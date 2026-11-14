# homeMod output interface: files, packages, environment, requires.
# Adapters consume this; modules never touch NixOS or Hjem options (R3).
{ config, lib, ... }:
let
  contract = import ../lib/contract.nix { inherit lib; };
  inherit (lib) mkOption types;

  fileType = types.attrsOf (types.submodule {
    options = {
      text = mkOption {
        type = types.nullOr types.lines;
        default = null;
        description = "Generated file text.";
      };
      source = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Source file or directory.";
      };
    };
  });
in
{
  options = {
    files = mkOption {
      type = fileType;
      default = { };
      description = "Files relative to the config directory (~/.config), by path.";
      apply = files:
        let
          invalid = builtins.attrNames
            (lib.filterAttrs (_: file: (file.text == null) == (file.source == null)) files);
        in
        if invalid == [ ] then
          files
        else
          throw "homeMod: files.${lib.concatStringsSep ", files." invalid} must define exactly one of `text` or `source`.";
    };

    packages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Packages for the user.";
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Session environment variables.";
    };

    requires = mkOption {
      type = contract.requiresType;
      default = contract.emptyRequires;
      description = "Capabilities this user configuration needs from the host (R4: capabilities, not packages).";
    };
  };
}
