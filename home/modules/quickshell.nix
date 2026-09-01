{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.myHome.quickshell;
  generatedSettings = pkgs.writeText "Generated.qml" ''
    pragma Singleton
    import QtQuick

    QtObject {
      readonly property int barHeight: ${toString cfg.barHeight}
      readonly property color background: ${builtins.toJSON cfg.background}
      readonly property color foreground: ${builtins.toJSON cfg.foreground}
      readonly property string label: ${builtins.toJSON cfg.label}
    }
  '';
  configDirectory = pkgs.runCommand "quickshell-${cfg.activeConfig}" {} ''
    mkdir -p $out
    cp -R ${../quickshell/shared}/. $out/
    cp ${generatedSettings} $out/Generated.qml
  '';
in {
  options.myHome.quickshell = {
    enable = lib.mkEnableOption "the shared Quickshell demo";
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start Quickshell through its Home Manager system user service.";
    };
    activeConfig = lib.mkOption {
      type = lib.types.str;
      default = "shared";
      description = "Name of the Quickshell configuration to activate.";
    };
    barHeight = lib.mkOption {
      type = lib.types.ints.positive;
      default = 32;
      description = "Height of the generated Quickshell top bar.";
    };
    background = lib.mkOption {
      type = lib.types.str;
      default = "#1e1e2e";
      description = "Background color for the Quickshell bar.";
    };
    foreground = lib.mkOption {
      type = lib.types.str;
      default = "#cdd6f4";
      description = "Foreground color for the Quickshell label.";
    };
    label = lib.mkOption {
      type = lib.types.str;
      default = "NixOS";
      description = "Text rendered by the Quickshell demo bar.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.quickshell = {
      enable = true;
      configs.${cfg.activeConfig} = configDirectory;
      activeConfig = cfg.activeConfig;
      systemd.enable = cfg.autostart;
    };
  };
}