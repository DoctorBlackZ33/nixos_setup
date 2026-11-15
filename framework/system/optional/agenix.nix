# Provider for `secrets.<name>` on NixOS, backed by agenix + agenix-rekey.
#
# It lives outside the discovered module sets: the fleet builder imports it,
# together with both upstream modules, only when the config flake sets
# `framework.secrets`. The rekey module refuses to evaluate without a master
# identity, even on hosts that have no secret.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  inherit (config.contract) facts wanted;
  cfg = config.sysMod.secrets;

  file = name: cfg.directory + "/${name}.age";
  available = lib.filterAttrs (name: _: builtins.pathExists (file name)) wanted.secrets;

  # A secret has exactly one reader: the user who asked, or root when the
  # system asked.
  owner = want:
    let
      source = builtins.head want.sources;
    in
    if lib.hasPrefix "user " source then lib.removePrefix "user " source else "root";
in
{
  options.sysMod.secrets = {
    directory = mkOption {
      type = types.path;
      description = "Directory holding `<name>.age` and `rekeyed/<deployment>/`.";
    };
    masterIdentities = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = "Passed to `age.rekey.masterIdentities` (identity stubs, no private key material).";
    };
    extraEncryptionPubkeys = mkOption {
      type = types.listOf types.raw;
      default = [ ];
      description = "Passed to `age.rekey.extraEncryptionPubkeys` (backup recipients).";
    };
  };

  config = {
    age.rekey = {
      storageMode = "local";
      localStorageDir = cfg.directory + "/rekeyed/${facts.name}";
      inherit (cfg) masterIdentities extraEncryptionPubkeys;
      hostPubkey = lib.mkIf (facts.hostKey != null) facts.hostKey;
    };

    age.secrets = lib.mapAttrs
      (name: want: {
        rekeyFile = file name;
        owner = lib.mkDefault (owner want);
        inherit (want) mode;
      })
      available;

    contract.secretsDirectory = config.age.secretsDir;
    contract.provides.secrets = lib.mapAttrs (name: _: available ? ${name}) wanted.secrets;

    assertions =
      # Asked of every request, with or without a ciphertext: two readers of
      # one secret would otherwise only surface once the file exists.
      lib.mapAttrsToList
        (name: want: {
          assertion = builtins.length want.sources == 1;
          message = ''
            host '${facts.name}': secret '${name}' is requested by ${lib.concatStringsSep ", " want.sources}.
            A secret has exactly one reader here; give each consumer its own secret.
          '';
        })
        wanted.secrets
      # The user layer is told `<secretsDir>/<name>`; a moved secret would
      # make that path wrong.
      ++ lib.mapAttrsToList
        (name: _: {
          assertion = config.age.secrets.${name}.path == "${config.age.secretsDir}/${name}";
          message = "host '${facts.name}': age.secrets.${name}.path must stay at its default; modules are handed that path.";
        })
        available;
  };
}
