{ config, lib, pkgs, ... }:
let
  cfg = config.system.desktop;
in
{
  options.system.desktop = {
    enable = lib.mkEnableOption "enable desktop configuration";

    hyprland = {
      enable = lib.mkEnableOption "enable hyprland";
    };

    niri = {
      enable = lib.mkEnableOption "enable niri";
    };
  };
  
  config = lib.mkIf cfg.enable {
    programs.hyprland = lib.mkIf cfg.hyprland.enable {
      enable = true;
      xwayland.enable = true;
    };

    programs.niri = lib.mkIf cfg.niri.enable {
      enable = true;
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = "gtk";
    };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    fonts.packages = with pkgs; [
      fira-code
      jetbrains-mono
    ];
  };
}
