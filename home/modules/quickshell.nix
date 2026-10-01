{ config, lib, pkgs, ... }:

let
  cfg = config.myHome.quickshell;
  files = lib.mapAttrs' (name: entry:
    lib.nameValuePair ".config/quickshell/${cfg.activeConfig}/${name}" {
      inherit (entry) source recursive force;
    }) cfg.files;
  policyFile = ''
    import QtQuick
    import Quickshell

    QtObject {
        readonly property string label: ${builtins.toJSON cfg.label}
        readonly property int clockPrecision: ${cfg.clockPrecision}
        readonly property string clockFormat: ${builtins.toJSON cfg.clockFormat}
    }
  '';
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
    clockPrecision = lib.mkOption {
      type = lib.types.str;
      default = "SystemClock.Minutes";
      description = "Quickshell SystemClock precision enum member to render.";
    };
    clockFormat = lib.mkOption {
      type = lib.types.str;
      default = "yyyy-MM-dd HH:mm";
      description = "Qt date-time format string used to render the clock.";
    };
    label = lib.mkOption {
      type = lib.types.str;
      default = "desktop";
      description = "Role label shown in the desktop bar.";
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
    home.file = files // {
      ".config/quickshell/${cfg.activeConfig}/DesktopPolicy.qml".text = policyFile;
    };
  };
}
