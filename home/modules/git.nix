{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.git;
in {
  options.myHome.git = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Git for this home profile.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git.enable = true;
  };
}
