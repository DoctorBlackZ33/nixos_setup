# homeMod output interface: files, packages, environment, requires.
# Adapters consume it; modules never touch NixOS or Hjem options (R3).
{ lib, framework, secretsDirectory, ... }:
let
  inherit (lib) mkOption types;

  quoted = lib.concatMapStringsSep ", " (path: "\"${path}\"");
in
{
  options = {
    files = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          text = mkOption {
            type = types.nullOr types.lines;
            default = null;
            description = "Generated file text.";
          };
          source = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Source file, directory or derivation output.";
          };
        };
      });
      default = { };
      example = { ".config/git/config".text = "..."; };
      description = "Files by path relative to the home directory.";
      apply = files:
        let
          escaping = lib.filter
            (path: path == "" || lib.hasPrefix "/" path || lib.elem ".." (lib.splitString "/" path))
            (builtins.attrNames files);
          ambiguous = builtins.attrNames
            (lib.filterAttrs (_: file: (file.text == null) == (file.source == null)) files);
        in
        if escaping != [ ] then
          throw "homeMod: files ${quoted escaping} must be paths inside the home directory (relative, without `..`)."
        else if ambiguous != [ ] then
          throw "homeMod: files ${quoted ambiguous} must define exactly one of `text` or `source`."
        else
          files;
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Packages for the user (R5: always Nix derivations).";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Session environment variables.";
    };

    requires = mkOption {
      type = framework.contract.requiresType;
      description = "Capabilities this user configuration needs from the host (R4: capabilities, not packages).";
    };

    secretPath = mkOption {
      type = types.functionTo types.str;
      readOnly = true;
      default = name:
        if secretsDirectory == null then
          throw "homeMod: secret '${name}' has no runtime path because this host has no secrets backend"
        else
          "${secretsDirectory}/${name}";
      defaultText = lib.literalExpression ''name: "''${secretsDirectory}/''${name}"'';
      description = ''
        Runtime path of a secret requested with `requires.secrets.<name>`
        (R8: a path, never the value).
      '';
    };
  };
}
