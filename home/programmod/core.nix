{ config, lib, pkgs, ... }:
let
  inherit (lib) mapAttrs mapAttrsToList mkOption types;

  filesType = types.attrsOf (types.submodule {
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
      description = "Files relative to the config directory (~/.config), by path.";
      type = filesType;
      default = { };
      apply = files:
        let
          invalid = builtins.attrNames (lib.filterAttrs (_: file: (file.text == null) == (file.source == null)) files);
        in
        if invalid == [ ] then
          files
        else
          throw "programmod: files.${lib.concatStringsSep ", files." invalid} must define exactly one of `text` or `source`.";
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

    build.files = mkOption {
      type = types.attrsOf types.path;
      readOnly = true;
      description = "Generated or sourced files by path.";
    };
    build.configDir = mkOption {
      type = types.package;
      readOnly = true;
      description = "A ~/.config-shaped tree containing all generated and sourced files.";
    };
    build.loadEnv = mkOption {
      type = types.package;
      readOnly = true;
      description = "A POSIX shell script exporting the standalone environment.";
    };
  };

  config = {
    build.files = mapAttrs (path: file:
      if file.text != null then
        pkgs.writeText (builtins.baseNameOf path) file.text
      else
        file.source
    ) config.files;

    build.configDir = pkgs.linkFarm "programmod-config" (mapAttrsToList (path: source: {
      name = path;
      path = source;
    }) config.build.files);

    build.loadEnv = pkgs.writeShellScript "programmod-load-env" (
      lib.concatMapStringsSep "\n" (name: "export ${name}=${lib.escapeShellArg config.environment.${name}}")
        (builtins.attrNames config.environment)
    );
  };
}
