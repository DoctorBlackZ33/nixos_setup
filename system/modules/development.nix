{ pkgs, ... }:

{
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
}
