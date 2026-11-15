{ config, lib, pkgs, framework, ... }:
let
  inherit (lib) mkOption types;
  inherit (framework) sections;
  cfg = config.fish;

  fishQuote = value: "'${lib.replaceStrings [ "\\" "'" ] [ "\\\\" "\\'" ] value}'";

  interactive =
    lib.mapAttrsToList (name: value: "alias ${name} ${fishQuote value}") cfg.aliases
    ++ lib.optional (cfg.commandColor != null) "set -g fish_color_command ${fishQuote cfg.commandColor}";

  environmentText = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: value: "set -gx ${name} ${fishQuote value}") config.environment);
in
{
  options.fish = {
    enable = lib.mkEnableOption "fish";
    package = lib.mkPackageOption pkgs "fish" { nullable = true; };

    aliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = { ll = "ls -lah"; };
      description = "Interactive aliases.";
    };

    commandColor = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "brcyan";
      description = "Value of `fish_color_command`; null keeps fish's own.";
    };

    sections = sections.option ''
      Named, ordered sections of config.fish. Integrations from other modules
      use the default order; `settings` and `environment` come first.
    '';
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    fish.sections = {
      settings = lib.mkIf (interactive != [ ]) {
        order = sections.order.early;
        text = lib.concatStringsSep "\n" (
          [ "if status is-interactive" ] ++ map (line: "    ${line}") interactive ++ [ "end" ]
        );
      };
      environment = lib.mkIf (config.environment != { }) {
        order = sections.order.before;
        text = environmentText;
      };
    };

    files.".config/fish/config.fish".text = sections.render {
      inherit (cfg) sections;
      comment = "#";
    };
  };
}
