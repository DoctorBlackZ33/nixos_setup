# userConf for black. Every profile is imported everywhere (R1) and gates
# itself on host facts, so the same user lands on a server without a
# compositor or an IDE.
{ ... }:
{
  imports = [
    ./cli.nix
    ./development.nix
    ./desktop.nix
    ./nvim.nix
    ./browsers.nix
  ];
}
