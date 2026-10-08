{ ... }:
{
  flake.modules.nixos = {
    sysMod-desktop = ./desktop.nix;
    sysMod-development = ./development.nix;
    sysMod-nix-settings = ./nix-settings.nix;
    sysMod-networking = ./networking.nix;
    sysMod-tty = ./tty.nix;
  };
}
