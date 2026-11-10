{ pkgs, ... }:

{
  packages = with pkgs; [
    bashInteractive
    btop
    grim
    kitty
    wl-clipboard
  ];

  hyprland.enable = true;
  quickshell.enable = true;
  mako.enable = true;
  fuzzel.enable = true;
}
