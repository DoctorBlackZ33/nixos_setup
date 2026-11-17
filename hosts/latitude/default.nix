# black's workstation on the Latitude 5420: bare metal, one account, a
# graphical login. Identity comes from users/black and hosts/latitude/facts.nix;
# this file decides what the account may do here and how the machine boots.
{ pkgs, ... }:
{
  imports = [ ./hardware.nix ];

  sysMod.locale = {
    timeZone = "Europe/Zurich";
    defaultLocale = "en_US.UTF-8";
    keyMap = "us";
  };

  sysMod.greeter = {
    enable = true;
    arguments = [ "--time" ];
  };

  # The laptop is expected to have sound; providers only act on a request.
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

  # Intel Iris Xe hardware decode, battery, thermal and firmware support.
  hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
  services.upower.enable = true;
  services.thermald.enable = true;
  services.power-profiles-daemon.enable = true;
  services.fwupd.enable = true;

  system.stateVersion = "26.05";
}
