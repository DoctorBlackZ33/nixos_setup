# system-manager adapter: the portable part of the system layer on a
# non-NixOS host. Users are delivered standalone; their requirements arrive as
# `contract.userRequests`, so this evaluation still reconciles for them.
{ config, lib, ... }:
let
  inherit (config.contract) facts;
  platform = config.nixpkgs.hostPlatform;
in
{
  imports = [ ./contract.nix ];

  config = {
    nixpkgs.hostPlatform = lib.mkDefault facts.platform;

    assertions = [
      {
        assertion = (platform.system or platform) == facts.platform;
        message = ''
          host '${facts.name}': nixpkgs.hostPlatform disagrees with the platform fact
          "${facts.platform}". Change hosts/<host>/facts.nix, not the option.
        '';
      }
      {
        assertion = config.contract.provides.secrets == { };
        message = ''
          host '${facts.name}': contract.provides.secrets is declared, but only NixOS hosts
          have a secrets backend.
        '';
      }
    ];
  };
}
