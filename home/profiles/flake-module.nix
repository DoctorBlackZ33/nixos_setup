{ ... }:

{
  flake.modules.programmod = {
    profile-base = ./base.nix;
    profile-desktop = ./desktop.nix;
    profile-development = ./development.nix;
  };
}
