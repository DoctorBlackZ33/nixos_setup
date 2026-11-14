# Hyprland  Module structure (enable/settings/sections with explicit
# order + text) is taken from my-nixos' hyprland; the rendering keeps the
# proven hl.config/dofile/policy layout. Requirements replace that module's
# `osConfig.programs.hyprland.enable` assertion with the host contract.
{ config, lib, ... }:
let
  helpers = import ../lib/helpers.nix { inherit lib; };
  cfg = config.hyprland;

  fragmentLines = map
    (fragment: "dofile(${builtins.toJSON (toString fragment)})")
    cfg.fragments;
  startupLines = map
    (command: "hl.on(\"hyprland.start\", function() hl.exec_cmd(${builtins.toJSON command}) end)")
    cfg.startupCommands;
in
{
  options.hyprland = helpers.mkProgramOptions { name = "Hyprland"; package = null; } // {
    fragments = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
      default = [ ];
      description = "Ordered Hyprland Lua fragments to load.";
    };
    startupCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Commands executed when Hyprland starts.";
    };
    floatingToggleChord = lib.mkOption {
      type = lib.types.str;
      default = "SUPER + V";
      description = "Chord that toggles floating windows.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    hyprland.sections.settings = lib.mkIf (cfg.settings != { }) {
      order = helpers.orders.settings;
      text = "hl.config(${lib.generators.toLua { } cfg.settings})";
    };

    hyprland.sections.sources = lib.mkIf (cfg.fragments != [ ]) {
      order = 400;
      text = lib.concatStringsSep "\n" fragmentLines;
    };

    hyprland.sections.policy = {
      order = helpers.orders.policy;
      text = "hl.bind(${builtins.toJSON cfg.floatingToggleChord}, hl.dsp.exec_cmd(\"hyprctl dispatch togglefloating\"))";
    };

    hyprland.sections.startup = lib.mkIf (cfg.startupCommands != [ ]) {
      order = helpers.orders.startup;
      text = lib.concatStringsSep "\n" startupLines;
    };

    files."hypr/hyprland.lua".text = helpers.renderSections {
      sections = cfg.sections;
      comment = "--";
    };

    requires.services.hyprland = { };
    requires.portals = [ "hyprland" "gtk" ];
    requires.facts."gpu.vendor" = { required = true; };
  };
}
