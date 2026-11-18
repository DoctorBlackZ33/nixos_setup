{ pkgs, ... }:
{
  imports = [ ../common/vm-hardware.nix ];

  sysMod.locale = {
    timeZone = "Europe/Zurich";
    defaultLocale = "en_US.UTF-8";
    keyMap = "us";
  };

  sysMod.greeter = {
    enable = true;
    arguments = [ "--time" ];
  };

  contract.requires.services.pipewire = { };

  sysMod.accounts.black = {
    groups = [
      "wheel"
      "networkmanager"
      "video"
      "input"
    ];
    hashedPassword = "$6$1StjVR6GUNDUdpRG$OyONcvDBTs/kgXZJguIhqJfgNmoDY8oAx6qGjkKjRq8BOQg1UuajbyoKT2fMxPbB5silVrVKmhgooGRYoAekM.";
  };

  # Kept for compatibility
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  services.upower.enable = true;
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;
  services.fwupd.enable = true;

  system.stateVersion = "26.05";
}
