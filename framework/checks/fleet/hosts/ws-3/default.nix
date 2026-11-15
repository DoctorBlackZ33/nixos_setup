# No users: the host itself asks for audio.
{ ... }:
{
  imports = [ ../common/nixos.nix ];

  contract.requires.services.pipewire = { };
}
