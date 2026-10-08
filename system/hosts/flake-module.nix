{ ... }:
{
  flake.modules.nixos = {
    hostMod-vm = ./vm/profile-vm.nix;
  };
}
