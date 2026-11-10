{ config, lib, pkgs, ... }:

let
  cfg = config.hyprland;
  lua = lib.generators.toLua { };
  fragmentLines = map (fragment:
    "dofile(${builtins.toJSON "${fragment}"})") cfg.fragments;
  floatingToggleLine =
    "hl.bind(${builtins.toJSON config.desktopPolicy.hyprland.floatingToggleChord}, hl.dsp.exec_cmd(\"hyprctl dispatch togglefloating\"))";
  startupLines = map (command:
    "hl.on(\"hyprland.start\", function() hl.exec_cmd(${builtins.toJSON command}) end)")
    cfg.startupCommands;
in
{
  options.hyprland = lib.programmod.mkProgramOptions {
    name = "hyprland";
    package = null;
  } // {
    fragments = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
      default = [ ];
      description = "Ordered Hyprland Lua fragments to load.";
    };
    startupCommands = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Commands to execute when Hyprland starts.";
    };
  };

  options.desktopPolicy.hyprland.floatingToggleChord = lib.mkOption {
    type = lib.types.str;
    default = "SUPER + V";
    description = "The chord that toggles floating windows in Hyprland.";
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    hyprland.sections.settings = lib.mkIf (cfg.settings != { })
      (lib.programmod.dag.entryBefore [ "sources" ] "hl.config(${lua cfg.settings})");
    hyprland.sections.sources = lib.mkIf (cfg.fragments != [ ])
      (lib.programmod.dag.entryBefore [ "policy" ] (lib.concatStringsSep "\n" fragmentLines));
    hyprland.sections.policy = lib.programmod.dag.entryBefore [ "startup" ] floatingToggleLine;
    hyprland.sections.startup = lib.mkIf (cfg.startupCommands != [ ])
      (lib.programmod.dag.entryAfter [ "policy" ] (lib.concatStringsSep "\n" startupLines));

    files."hypr/hyprland.lua".text = lib.programmod.renderSections {
      inherit (cfg) sections;
      comment = "--";
    };
  };
}
