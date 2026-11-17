# Hyprland user configuration. The compositor itself is a system capability
# (`requires.services.hyprland`), so this module installs no package.
{ config, lib, framework, ... }:
let
  inherit (lib) mkOption types;
  inherit (framework) sections;
  cfg = config.hyprland;
in
{
  options.hyprland = {
    enable = lib.mkEnableOption "the Hyprland user configuration";

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Passed to `hl.config` through `lib.generators.toLua`.";
    };

    fragments = mkOption {
      type = types.listOf (types.either types.path types.str);
      default = [ ];
      description = "Lua files inlined in order after the settings.";
    };

    startupCommands = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Commands executed when Hyprland starts.";
    };

    floatingToggleChord = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "SUPER + V";
      description = "Chord that toggles floating windows; null binds nothing.";
    };

    sections = sections.option "Named, ordered sections of hyprland.lua.";
  };

  config = lib.mkIf cfg.enable {
    hyprland.sections = {
      settings = lib.mkIf (cfg.settings != { }) {
        order = sections.order.before;
        text = "hl.config(${lib.generators.toLua { } cfg.settings})";
      };

      sources = lib.mkIf (cfg.fragments != [ ]) {
        text = lib.concatMapStringsSep "\n"
          (fragment: builtins.readFile fragment)
          cfg.fragments;
      };

      policy = lib.mkIf (cfg.floatingToggleChord != null) {
        order = sections.order.after;
        text = "hl.bind(${builtins.toJSON cfg.floatingToggleChord}, hl.dsp.exec_cmd(\"hyprctl dispatch togglefloating\"))";
      };

      startup = lib.mkIf (cfg.startupCommands != [ ]) {
        order = sections.order.late;
        text = lib.concatMapStringsSep "\n"
          (command: "hl.on(\"hyprland.start\", function() hl.exec_cmd(${builtins.toJSON command}) end)")
          cfg.startupCommands;
      };
    };

    files.".config/hypr/hyprland.lua".text = sections.render {
      inherit (cfg) sections;
      comment = "--";
    };

    requires = {
      services.hyprland = { };
      portals.hyprland = { };
      portals.gtk = { };
      facts."gpu.vendor" = { };
    };
  };
}
