{ config, lib, pkgs, ... }:
let
  helpers = import ../lib/helpers.nix { inherit lib; };
  cfg = config.quickshell;

  sourceFiles = lib.mapAttrs'
    (name: file: lib.nameValuePair "quickshell/${cfg.activeConfig}/${name}" { inherit (file) source; })
    cfg.files;

  renderedSections = helpers.renderSections {
    inherit (cfg) sections;
    comment = "//";
  };

  indent = text: lib.concatMapStringsSep "\n" (line: "    ${line}") (lib.splitString "\n" text);

  policyFile = ''
    import QtQuick
    import Quickshell

    QtObject {
    ${indent renderedSections}
    }
  '';
in
{
  options.quickshell = helpers.mkProgramOptions { name = "quickshell"; package = pkgs.quickshell; } // {
    activeConfig = lib.mkOption {
      type = lib.types.str;
      description = "Name of the resolved Quickshell configuration.";
    };
    files = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options.source = lib.mkOption {
          type = lib.types.path;
          description = "Source path for a Quickshell file or directory.";
        };
      });
      default = { };
      description = "Files and directory trees for the active Quickshell configuration.";
    };
    clockPrecision = lib.mkOption {
      type = lib.types.str;
      default = "SystemClock.Minutes";
      description = "Quickshell SystemClock precision enum member.";
    };
    clockFormat = lib.mkOption {
      type = lib.types.str;
      default = "yyyy-MM-dd HH:mm";
      description = "Qt date-time format used by the clock.";
    };
    label = lib.mkOption {
      type = lib.types.str;
      default = "desktop";
      description = "Role label displayed in the bar.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    files = sourceFiles // {
      "quickshell/${cfg.activeConfig}/DesktopPolicy.qml".text = policyFile;
    };

    quickshell.sections.settings = lib.mkIf (cfg.settings != { }) {
      order = helpers.orders.settings;
      text = "readonly property var settings: JSON.parse(${builtins.toJSON (builtins.toJSON cfg.settings)})";
    };

    quickshell.sections.policy = {
      order = helpers.orders.policy;
      text = ''
        readonly property string label: ${builtins.toJSON cfg.label}
        readonly property int clockPrecision: ${cfg.clockPrecision}
        readonly property string clockFormat: ${builtins.toJSON cfg.clockFormat}
      '';
    };

    requires.services.pipewire = { };
  };
}
