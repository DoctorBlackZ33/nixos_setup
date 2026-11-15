{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.sysMod.accounts;

  shells = {
    bash = pkgs.bashInteractive;
    fish = pkgs.fish;
    zsh = pkgs.zsh;
  };

  uses = shell: lib.any (account: account.shell == shell) (lib.attrValues cfg);
in
{
  options.sysMod.accounts = mkOption {
    type = types.attrsOf (types.submodule {
      options = {
        description = mkOption {
          type = types.str;
          default = "";
        };
        groups = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        shell = mkOption {
          type = types.enum (lib.attrNames shells);
          default = "bash";
          description = "Login shell. The matching `programs.<shell>` is enabled for it.";
        };
        hashedPassword = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            Password hash. It is world-readable in the Nix store, so use it for
            throwaway machines only; real hosts use `hashedPasswordFile`.
          '';
        };
        hashedPasswordFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Runtime path of a file holding the password hash, for example a secret.";
        };
        authorizedKeys = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "SSH public keys allowed to log in.";
        };
      };
    });
    default = { };
    description = "Declarative login accounts.";
  };

  config = lib.mkIf (cfg != { }) {
    users.mutableUsers = lib.mkDefault false;

    programs.fish.enable = lib.mkIf (uses "fish") true;
    programs.zsh.enable = lib.mkIf (uses "zsh") true;

    users.users = lib.mapAttrs
      (_: account: {
        isNormalUser = true;
        inherit (account) description hashedPassword hashedPasswordFile;
        extraGroups = account.groups;
        shell = shells.${account.shell};
        openssh.authorizedKeys.keys = account.authorizedKeys;
      })
      cfg;

    assertions = lib.mapAttrsToList
      (name: account: {
        assertion = account.hashedPassword == null || account.hashedPasswordFile == null;
        message = "sysMod.accounts.${name}: set hashedPassword or hashedPasswordFile, not both.";
      })
      cfg;
  };
}
