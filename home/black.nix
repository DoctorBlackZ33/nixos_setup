{ config, lib, osConfig, pkgs, ... }:

let
  liveRice = path: config.lib.file.mkOutOfStoreSymlink "${osConfig.rice.sourceRoot}/${path}";
  riceFile = path: {
    source = if osConfig.rice.devMode then liveRice path else ../${path};
  };
in
{
  home.username = "black";
  home.homeDirectory = "/home/black";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  programs.git.enable = true;
  programs.neovim.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  home.packages = with pkgs; [
    bashInteractive
    btop
    fuzzel
    grim
    kitty
    mako
    waybar
    wl-clipboard
  ];

  home.file.".config/hypr/hyprland.conf" = riceFile "rice/hyprland.conf";
  home.file.".config/waybar/config" = riceFile "rice/waybar/config";
  home.file.".config/waybar/style.css" = riceFile "rice/waybar/style.css";
  home.file.".config/mako/config" = riceFile "rice/mako/config";
  home.file.".config/fuzzel/fuzzel.ini" = riceFile "rice/fuzzel/fuzzel.ini";
}
