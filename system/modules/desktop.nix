{ config, lib, pkgs, ... }:
#let ... in is just normal nix syntax, it declares locally scoped variables
let
  # config is what comes out after evaluation assigned values to all the options
  cfg = config.system.desktop;
in
{
  # options are exposed first and tell what is configurable about a module
  options.system.desktop = {
    enable = lib.mkEnableOption "enable desktop configuration";

    hyprland = {
      enable = lib.mkEnableOption "enable hyprland";
    };

    niri = {
      enable = lib.mkEnableOption "enable niri";
    };
  };
  /* 
  this is just boilerplate, config = {...} is implicitly part of every module but only needs to be explicit when working
  with other top level keys like options. the path is:
  assign cfg with just a reference without evaluation
  declare the options and add them to the set
  -- declaration must be finished for evaluation to work --
  actually implement those options elsewhere for example system.desktop.enable = true
  -- config is built lazily (mentally as sort of a dependency graph)
  evaluate config = lib.mkIf cfg.enable and resolve cfg.enable and actually calculate this expression
  evaluate every relevant thing in that attribute set and deep merge it into the config set
  -- evaluation needs to be fully finished
  build the config set
  */
  config = lib.mkIf cfg.enable {
    programs.hyprland = lib.mkIf cfg.hyprland.enable {
      enable = true;
      xwayland.enable = true;
    };

    programs.niri = lib.mkIf cfg.niri.enable {
      enable = true;
    };

    services.displayManager.sddm = lib.mkIf (cfg.hyprland.enable || cfg.niri.enable) {
      enable = true;
      wayland.enable = true;
    };

    # xdg.portal is gemnini slop, programs.hyprland already enables xdg-desktop-portal-hyprland
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config = {
        common.default = [ "gtk" ];
        hyprland = {
          default = [ "gtk" ];
          # gemini says the gtk portal does not support screen capture on hyprland, this is why these functions use overrides, needs dependency checks
          "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
          "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        };
      };
    };
    # gemini says without security.rtkit.enable = true; audio could break down under high system pressure due to user scheduling
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    fonts.packages = with pkgs; [
      fira-code
      jetbrains-mono
    ];
  };
}
