{lib, ...}: let
  # Each host sets its own disk in flake.nix (lsblk; ls -l /dev/disk/by-id)
  device = lib.mkDefault (throw "set disko.devices.disk.main.device for this host in flake.nix (a /dev/disk/by-id path)");

  # CHANGE THESE VALUES!
  # >= RAM if you hibernate
  swapSize = "1G";

  # Do you want to live the impermanent life?
  # Only adds /persist (neededForBoot); resetting root on boot is left to iDN.
  # Must be true exactly when the iDN host includes the `impermanence` aspect.
  impermanence = false;

  # Encrypt the root with LUKS2? Desktops only: servers stay unencrypted.
  # Must be true exactly when the iDN host includes the `luks` aspect.
  # Give nixos-anywhere the passphrase with
  #   --disk-encryption-keys /tmp/secret.key <local file holding it>
  # Every boot asks for it on the console until iDN sets up the TPM.
  luks = false;

  # Also format a second disk, like iDN's disko-btrfs-data? Set its device in
  # flake.nix. With luks on, it gets the same passphrase; iDN opens it with a
  # keyfile instead, which the README's handoff step adds. It stays unmounted
  # until iDN takes over.
  data = false;

  maybeLuks = content:
    if luks
    then {
      type = "luks";
      # Opens as /dev/mapper/crypted, like in iDN
      name = "crypted";
      # Only read while formatting
      passwordFile = "/tmp/secret.key";
      settings.allowDiscards = true;
      inherit content;
    }
    else content;
in {
  disko.devices = {
    disk.main = {
      inherit device;
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            priority = 1;
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["umask=0077"];
            };
          };

          root = {
            priority = 2;
            size = "100%";
            content = maybeLuks {
              type = "btrfs";
              # force-overwrite any existing fs and setting nixos as label
              extraArgs = [
                "-L"
                "nixos"
                "-f"
              ];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/persist" = lib.mkIf impermanence {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                # To hibernate, set iDN's resumeOffset setting after install to
                # sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
                "/swap" = {
                  mountpoint = "/swap";
                  swap.swapfile.size = swapSize;
                };
              };
            };
          };
        };
      };
    };
  };

  disko.devices.disk.data = lib.mkIf data {
    device = lib.mkDefault (throw "set disko.devices.disk.data.device for this host in flake.nix (a /dev/disk/by-id path)");
    type = "disk";
    content = {
      type = "gpt";
      partitions.data = {
        size = "100%";
        content = let
          btrfs = {
            type = "btrfs";
            extraArgs = [
              "-L"
              "data"
              "-f"
            ];
          };
        in
          if luks
          then {
            type = "luks";
            # Opens as /dev/mapper/data, like in iDN
            name = "data";
            # Only read while formatting
            passwordFile = "/tmp/secret.key";
            # iDN opens it after root, not in the initrd
            initrdUnlock = false;
            content = btrfs;
          }
          else btrfs;
      };
    };
  };

  fileSystems = lib.mkIf impermanence {"/persist".neededForBoot = true;};
}
