{ config, lib, pkgs, ... }:
let
  helpers = import ../lib/helpers.nix { inherit lib; };
  cfg = config.fish;
  environment = config.environment;

  fishQuote = value: "'${lib.replaceStrings [ "\\" "'" ] [ "\\\\" "\\'" ] value}'";

  environmentLines = lib.concatMapStringsSep "\n"
    (name: "set -gx ${name} ${fishQuote environment.${name}}")
    (builtins.attrNames environment);

  settingsLines =
    [ "if status is-interactive" ]
    ++ lib.mapAttrsToList
      (name: value: "    alias ${name} ${lib.escapeShellArg value}")
      cfg.settings.aliases
    ++ [
      "    set -g fish_color_command ${lib.escapeShellArg cfg.settings.commandColor}"
      "end"
    ];
in
{
  options.fish = helpers.mkProgramOptions { name = "fish"; package = pkgs.fish; };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    fish.settings.commandColor = lib.mkDefault "brcyan";
    fish.settings.aliases = lib.mkDefault { };

    fish.sections.settings = lib.mkIf (cfg.settings != { }) {
      order = helpers.orders.settings;
      text = lib.concatStringsSep "\n" settingsLines;
    };

    fish.sections.environment = lib.mkIf (environment != { }) {
      order = helpers.orders.environment;
      text = environmentLines;
    };

    files."fish/config.fish".text = helpers.renderSections {
      sections = cfg.sections;
      comment = "#";
    };
  };
}
