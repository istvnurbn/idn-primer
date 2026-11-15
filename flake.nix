{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.treefmt-nix.url = "github:numtide/treefmt-nix";
  inputs.treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {
    self,
    nixpkgs,
    disko,
    treefmt-nix,
    ...
  }: let
    # For Hetzner cloud servers or QEMU guests; the two configurations differ only in system
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
    # nix fmt and the formatting check, on every system the primer is run from
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    treefmt = forAllSystems (system:
      treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} {
        projectRootFile = "flake.nix";
        programs.alejandra.enable = true;
      });
  in {
    formatter = forAllSystems (system: treefmt.${system}.config.build.wrapper);
    checks = forAllSystems (system: {formatting = treefmt.${system}.config.build.check self;});
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
        # per machine, if its iDN host uses Nyx (vermilion: its kernel is only in Nyx's cache, so iDN's first build would compile it):
        # {nix.settings = {substituters = ["https://nyx-cache.chaotic.cx/"]; trusted-public-keys = ["nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="];};}
      ];
    };
  };
}
