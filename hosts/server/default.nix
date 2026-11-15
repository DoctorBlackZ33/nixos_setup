# Reference server: the same libvirt guest, headless. Everything it runs
# follows from `kind = "server"` in its facts.
{ ... }:
{
  imports = [ ../common/vm.nix ];
}
