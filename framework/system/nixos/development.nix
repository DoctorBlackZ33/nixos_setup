{ config, lib, pkgs, ... }:
{
  options.sysMod.development.enable = lib.mkEnableOption "compilers, language servers and build tools for all users";

  config = lib.mkIf config.sysMod.development.enable {
    environment.systemPackages = with pkgs; [
      alejandra
      clang
      fd
      gcc
      gnumake
      just
      killall
      nil
      nixd
      pkg-config
      ripgrep
      tree
      unzip
      wget
    ];
  };
}
