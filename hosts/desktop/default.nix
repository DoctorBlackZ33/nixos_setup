{ ... }:
let
  host = import ./facts.nix;
in
{
  imports = [ ../common/vm.nix ];

  inherit (host) facts provides;

  networking.hostName = host.facts.hostName;
}
