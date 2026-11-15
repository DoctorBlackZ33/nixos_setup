# Values shared by the two reference hosts, which both describe the same
# libvirt guest. Real hosts get their own hardware file and their own values.
{ pkgs, ... }:
{
  imports = [ ./vm-hardware.nix ];

  boot.kernelPackages = pkgs.linuxPackages;

  sysMod.locale = {
    timeZone = "Europe/Zurich";
    defaultLocale = "en_US.UTF-8";
    keyMap = "us";
  };

  # The guest is reached with a password from the libvirt network only. A real
  # host lists `authorizedKeys` instead and leaves password logins off.
  sysMod.ssh = {
    enable = true;
    passwordAuthentication = true;
  };

  # Who black is comes from users/black/account.nix; these are the guest's
  # own decisions about that account.
  sysMod.accounts.black = {
    groups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    # Bootstrap password of the throwaway guest; it is readable in the store.
    # A real host uses `hashedPasswordFile` backed by a secret.
    hashedPassword = "$6$nixosdev$QyqUycwLZRiiEsmZ4jzHtrAwIZ8EdPikwJnmrFAygYLP9/LO2wGcFGF4UrykL8niiDRN76b8ayhPtTAG/Pj7x1";
  };

  system.stateVersion = "26.05";
}
