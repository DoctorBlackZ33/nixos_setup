{ config, lib, ... }:
let
  cfg = config.sysMod.accounts;
in
{
  options.sysMod.accounts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        description = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
        groups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };
        shell = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
        };
        hashedPassword = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
      };
    });
    default = { };
    description = "Immutable OS login accounts.";
  };

  config = lib.mkIf (config.facts.managed == "nixos" && cfg != { }) {
    users.mutableUsers = false;
    users.users = lib.mapAttrs
      (name: account: {
        isNormalUser = true;
        inherit (account) description hashedPassword;
        extraGroups = account.groups;
        shell = lib.mkIf (account.shell != null) account.shell;
      })
      cfg;
  };
}
