{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {
    nixpkgs,
    disko,
    ...
  }: let
    # For Hetzner cloud servers or QEMU guests; the two configurations differ only in `system`
    hetzner = system:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          ./configuration.nix
          "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
          {disko.devices.disk.main.device = "/dev/sda";}
          # per machine: {networking.hostName = "<name>";}
          # per machine, for IPv6 (required on IPv6-only servers; Hetzner assigns it statically):
          # {networking.useNetworkd = true; systemd.network.networks."10-uplink" = {matchConfig.Name = "en*"; networkConfig.DHCP = "ipv4"; address = ["<prefix>::1/64"]; routes = [{Gateway = "fe80::1";}];};}
        ];
      };
  in {
    # x86_64 Hetzner cloud servers
    nixosConfigurations.hetzner-cloud = hetzner "x86_64-linux";

    # aarch64 Hetzner cloud servers
    nixosConfigurations.hetzner-cloud-aarch64 = hetzner "aarch64-linux";

    # Use this for all other targets.
    nixosConfigurations.generic = nixpkgs.lib.nixosSystem {
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        ./hardware-configuration.nix
        # Non-free firmware for devices nixos-generate-config doesn't recognize
        {hardware.enableRedistributableFirmware = nixpkgs.lib.mkDefault true;}
        # per machine: {disko.devices.disk.main.device = "/dev/disk/by-id/<id>";}
        # per machine, with data = true: {disko.devices.disk.data.device = "/dev/disk/by-id/<id>";}
        # per machine: {networking.hostName = "<name>";}
      ];
    };
  };
}
