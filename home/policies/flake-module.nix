{ ... }:
{
  flake.modules.homeManager = {
    policy-desktop = ./desktop.nix;
    policy-laptop = ./laptop.nix;
  };
}
