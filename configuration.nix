{
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./disk-config.nix
    ./access.nix
  ];

  boot.loader = {
    # Use the systemd-boot EFI boot loader.
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = lib.mkDefault (throw "set networking.hostName for this host in flake.nix");

  nix.settings = {
    # Enable the Flakes feature and the accompanying new nix command-line tool
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  environment.systemPackages = with pkgs; [
    curl
    gitMinimal
    msedit
  ];

  system.stateVersion = "26.05";
}
