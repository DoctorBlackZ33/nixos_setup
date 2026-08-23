{ pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
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
