{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = {
    nixpkgs,
    disko,
    ...
  }: {
    # For x86_64 Hetzner cloud servers or QEMU guests
    nixosConfigurations.hetzner-cloud = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
        {disko.devices.disk.main.device = "/dev/sda";}
        # per machine: {networking.hostName = "<name>";}
      ];
    };

    # For aarch64 Hetzner cloud servers or QEMU guests
    nixosConfigurations.hetzner-cloud-aarch64 = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        "${nixpkgs}/nixos/modules/profiles/qemu-guest.nix"
        {disko.devices.disk.main.device = "/dev/sda";}
        # per machine: {networking.hostName = "<name>";}
      ];
    };

    # Use this for all other targets.
    nixosConfigurations.generic = nixpkgs.lib.nixosSystem {
      modules = [
        disko.nixosModules.disko
        ./configuration.nix
        ./hardware-configuration.nix
        # per machine: {disko.devices.disk.main.device = "/dev/disk/by-id/<id>";}
        # per machine: {networking.hostName = "<name>";}
      ];
    };
  };
}
