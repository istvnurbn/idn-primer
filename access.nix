# The only personal part of this repo: replace with your own.
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.steve = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMDFAQW9uPhDsi+CiCxfwon12iT0Earea6CznTniv1Ta steve@vermilion"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG9mUymT0rLNsntCzJp7Na4Rwj9fAMgfh1oSYmXuRvRK steve@hexley"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO+ge++JIgIQHrr14P1u0K+rF/NzfaTiBz+TRMmUfMHO steve@loophole"
    ];
  };

  security.sudo.wheelNeedsPassword = false;
}
