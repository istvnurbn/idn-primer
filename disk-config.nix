{lib, ...}: let
  # Each host sets its own disk in flake.nix (lsblk; ls -l /dev/disk/by-id)
  device = lib.mkDefault (throw "set disko.devices.disk.main.device for this host in flake.nix (a /dev/disk/by-id path)");

  # CHANGE THESE VALUES!
  # >= RAM if you hibernate
  swapSize = "1G";

  # Do you want to live the impermanent life?
  # Only adds /persist (neededForBoot); resetting root on boot is left to iDN.
  impermanence = false;
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
            content = {
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
                # If you hibernate, add two bits manually after install:
                #
                # boot.resumeDevice = "/dev/disk/by-partlabel/disk-main-root";
                # boot.kernelParams = [ "resume_offset=<N>" ];
                #
                # <N> comes from
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

  fileSystems = lib.mkIf impermanence {"/persist".neededForBoot = true;};
}
