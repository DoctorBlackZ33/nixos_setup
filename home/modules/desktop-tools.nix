{pkgs, ...}: {
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
}
