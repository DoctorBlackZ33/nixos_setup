{ config, lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.zoxide;
  zoxide = if cfg.package != null then lib.getExe cfg.package else "zoxide";
in
{
  options.zoxide = {
    enable = lib.mkEnableOption "zoxide";
    package = lib.mkPackageOption pkgs "zoxide" { nullable = true; };

    flags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--cmd=cd" ];
      description = "Flags passed to `zoxide init`.";
    };

    enableFishIntegration = mkOption {
      type = types.bool;
      default = true;
      description = "Initialise zoxide in fish when the fish module is enabled.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    fish.sections.zoxide = lib.mkIf (config.fish.enable && cfg.enableFishIntegration) {
      text = ''
        if status is-interactive
          ${lib.concatStringsSep " " ([ zoxide "init" "fish" ] ++ cfg.flags)} | source
        end
      '';
    };
  };
}
