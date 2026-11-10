{ config, lib, pkgs, ... }:

let
  cfg = config.fish;
  fishQuote = value: "'${lib.replaceStrings [ "\\" "'" ] [ "\\\\" "\\'" ] value}'";
  fishEnvironment = lib.concatMapStringsSep "\n" (name:
    "set -gx ${name} ${fishQuote config.environment.${name}}"
  ) (builtins.attrNames config.environment);
  settingsLines =
    [ "if status is-interactive" ]
    ++ lib.mapAttrsToList (name: value:
      "    alias ${name} ${lib.escapeShellArg value}"
    ) cfg.settings.aliases
    ++ [
      "    set -g fish_color_command ${lib.escapeShellArg cfg.settings.commandColor}"
      "end"
    ];
in
{
  options.fish = lib.programmod.mkProgramOptions {
    name = "fish";
    package = pkgs.fish;
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    fish.settings.commandColor = lib.mkDefault "brcyan";
    fish.settings.aliases = lib.mkDefault { };
    fish.sections.settings = lib.mkIf (cfg.settings != { })
      (lib.concatStringsSep "\n" settingsLines);

    fish.sections.programmod-environment = lib.mkIf (config.environment != { })
      (lib.programmod.dag.entryAfter [ "settings" ] fishEnvironment);

    files."fish/config.fish".text = lib.programmod.renderSections {
      inherit (cfg) sections;
      comment = "#";
    };
  };
}
