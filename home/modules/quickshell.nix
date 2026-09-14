{ config, lib, pkgs, ... }:

let
  cfg = config.myHome.quickshell;
  files = lib.mapAttrs' (name: entry:
    lib.nameValuePair ".config/quickshell/${cfg.activeConfig}/${name}" {
      inherit (entry) source recursive force;
    }) cfg.files;
in {
  options.myHome.quickshell = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the native Quickshell desktop shell.";
    };
    activeConfig = lib.mkOption {
      type = lib.types.str;
      description = "Name of the resolved Quickshell configuration.";
    };
    files = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ ... }: {
        options = {
          source = lib.mkOption {
            type = lib.types.path;
            description = "Resolved source path for this Quickshell entry.";
          };
          recursive = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Copy directory contents recursively instead of linking the root.";
          };
          force = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Allow Home Manager to replace an existing target.";
          };
        };
      }));
      default = {};
      description = "Resolved Quickshell files and directories.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.quickshell ];
    home.file = files;
  };
}
