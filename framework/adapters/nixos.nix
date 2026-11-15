# NixOS adapter: glue only. Identity comes from the host facts; fulfilment
# lives in provider modules under framework/system. Hosts with users
# additionally get ./nixos-users.nix.
{ config, lib, ... }:
let
  inherit (config.contract) facts;
in
{
  imports = [ ./contract.nix ];

  config = {
    networking.hostName = lib.mkDefault facts.hostName;
    nixpkgs.hostPlatform = lib.mkDefault facts.platform;

    # The inventory validates names and places checks using the facts, so the
    # system may not disagree with them.
    assertions = [
      {
        assertion = config.networking.hostName == facts.hostName;
        message = ''
          host '${facts.name}': networking.hostName is "${config.networking.hostName}" but the
          hostName fact is "${facts.hostName}". Change hosts/<host>/facts.nix, not the option.
        '';
      }
      {
        assertion = config.nixpkgs.hostPlatform.system == facts.platform;
        message = ''
          host '${facts.name}': nixpkgs.hostPlatform is "${config.nixpkgs.hostPlatform.system}" but
          the platform fact is "${facts.platform}". Change hosts/<host>/facts.nix, not the option.
        '';
      }
    ];
  };
}
