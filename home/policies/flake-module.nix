{ ... }:
{
  flake.modules.programmod = {
    policy-desktop = ./desktop.nix;
    policy-laptop = ./laptop.nix;
  };
}
