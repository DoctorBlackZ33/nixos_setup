{ pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.extra-substituters = [
    "https://attic.xuyh0120.win/lantian"
  ];
  nix.settings.extra-trusted-public-keys = [
    "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
  ];
  nix.settings.auto-optimise-store = true;
  nix.settings.builders-use-substitutes = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nix.optimise.automatic = true;

  environment.systemPackages = with pkgs; [
    alejandra
    clang
    curl
    fd
    gcc
    git
    gnumake
    jq
    just
    killall
    nil
    nixd
    pkg-config
    ripgrep
    rsync
    tree
    unzip
    wget
  ];

  programs.fish.enable = true;
}
