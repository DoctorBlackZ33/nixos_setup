# Shared hostConf values for the two simulated VM hosts.
{ pkgs, ... }:
{
  imports = [ ./vm-hardware.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";
  boot.kernelPackages = pkgs.linuxPackages;

  sysMod.locale = {
    timeZone = "Europe/Zurich";
    defaultLocale = "en_US.UTF-8";
    keyMap = "us";
  };

  sysMod.greeter = {
    enable = true;
    user = "black";
  };

  sysMod.accounts.black = {
    description = "Black";
    groups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    shell = pkgs.fish;
    # Bootstrap-only VM password. Change this value before using the VM for
    # anything sensitive.
    hashedPassword = "$6$nixosdev$QyqUycwLZRiiEsmZ4jzHtrAwIZ8EdPikwJnmrFAygYLP9/LO2wGcFGF4UrykL8niiDRN76b8ayhPtTAG/Pj7x1";
  };

  # The simulated hosts have no physical GPU. Force guest compositor and
  # OpenGL work onto software rendering, like the existing VM host.
  environment.sessionVariables = {
    LIBGL_ALWAYS_SOFTWARE = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  system.stateVersion = "26.05";
}
