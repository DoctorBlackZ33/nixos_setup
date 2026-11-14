{ config, lib, pkgs, ... }:
{
  config = {
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

    programs.fish.enable = lib.mkIf (config.facts.managed == "nixos") true;
  };
}
