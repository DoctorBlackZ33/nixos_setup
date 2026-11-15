# Login accounts. Where a user is deployed, the fleet builder fills in their
# identity from `users/<user>/account.nix`; a host adds groups, may override a
# value, and may declare accounts of its own.
{ config, lib, pkgs, framework, ... }:
let
  cfg = config.sysMod.accounts;

  shellPackages = {
    bash = pkgs.bashInteractive;
    fish = pkgs.fish;
    zsh = pkgs.zsh;
  };

  uses = shell: lib.any (account: account.shell == shell) (lib.attrValues cfg);
in
{
  options.sysMod.accounts = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule { options = framework.accounts.hostOptions; });
    default = { };
    description = "Declarative login accounts of this host.";
  };

  config = lib.mkIf (cfg != { }) {
    users.mutableUsers = lib.mkDefault false;

    programs.fish.enable = lib.mkIf (uses "fish") true;
    programs.zsh.enable = lib.mkIf (uses "zsh") true;

    users.users = lib.mapAttrs
      (_: account: {
        isNormalUser = true;
        inherit (account) description hashedPassword hashedPasswordFile;
        uid = lib.mkIf (account.uid != null) account.uid;
        extraGroups = account.groups;
        shell = shellPackages.${account.shell};
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
