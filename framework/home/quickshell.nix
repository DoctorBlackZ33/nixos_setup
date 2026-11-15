{ config, lib, pkgs, facts, framework, ... }:
let
  inherit (lib) mkOption types;
  inherit (framework) sections;
  cfg = config.quickshell;

  directory = ".config/quickshell/${cfg.activeConfig}";

  indent = text: lib.concatMapStringsSep "\n" (line: "    ${line}") (lib.splitString "\n" text);
in
{
  options.quickshell = {
    enable = lib.mkEnableOption "Quickshell";
    package = lib.mkPackageOption pkgs "quickshell" { nullable = true; };

    activeConfig = mkOption {
      type = types.str;
      default = "default";
      description = "Configuration name, as used by `quickshell --config <name>`.";
    };

    files = mkOption {
      type = types.attrsOf (types.submodule {
        options.source = mkOption {
          type = types.path;
          description = "Source file or directory.";
        };
      });
      default = { };
      description = "Files and directory trees of the active configuration.";
    };

    clockPrecision = mkOption {
      type = types.enum [ "Hours" "Minutes" "Seconds" ];
      default = "Minutes";
      description = "Member of Quickshell's `SystemClock` precision enum.";
    };

    clockFormat = mkOption {
      type = types.str;
      default = "yyyy-MM-dd HH:mm";
      description = "Qt date-time format of the clock.";
    };

    label = mkOption {
      type = types.str;
      default = facts.name;
      defaultText = lib.literalExpression "facts.name";
      description = "Label shown in the bar.";
    };

    sections = sections.option "Named, ordered property blocks of the generated DesktopPolicy.qml.";
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    quickshell.sections.policy.text = ''
      readonly property string label: ${builtins.toJSON cfg.label}
      readonly property int clockPrecision: SystemClock.${cfg.clockPrecision}
      readonly property string clockFormat: ${builtins.toJSON cfg.clockFormat}
    '';

    files =
      lib.mapAttrs' (name: file: lib.nameValuePair "${directory}/${name}" { inherit (file) source; }) cfg.files
      // {
        "${directory}/DesktopPolicy.qml".text = ''
          import QtQuick
          import Quickshell

          QtObject {
          ${indent (sections.render { inherit (cfg) sections; comment = "//"; })}
          }
        '';
      };
  };
}
