{ config, lib, pkgs, ... }:

let
  cfg = config.zoxide;
  zoxideExe = if cfg.package != null then lib.getExe cfg.package else "zoxide";
  fishIntegration = ''
    if status is-interactive
      ${lib.concatStringsSep " " ([ zoxideExe "init" "fish" ] ++ cfg.settings.options)} | source
    end
  '';
in
{
  options.zoxide = lib.programmod.mkProgramOptions {
    name = "zoxide";
    package = pkgs.zoxide;
  } // {
    enableFishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable zoxide's Fish integration.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;

    zoxide.settings.options = lib.mkDefault [ "--cmd=cd" ];

    fish.sections.zoxide = lib.mkIf cfg.enableFishIntegration (lib.mkDefault
      (lib.programmod.dag.entryAfter [ "settings" "programmod-environment" ] fishIntegration)
    );
  };
}
