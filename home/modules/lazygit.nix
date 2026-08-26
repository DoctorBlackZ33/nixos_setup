{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.lg;
in {
  options.myHome.lg = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable lg for lazygit tui operations";
    };
    enableFishIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the fish integration of lazygit";
    };
    shellWrapperName = lib.mkOption {
      type = lib.types.str;
      default = "lg";
      description = "The shorthand alias to use as the command to call lazygit from the terminal";
    };
  };
  config = lib.mkIf cfg.enable {
    programs.lazygit = {
      enable = true;
      enableFishIntegration = cfg.enableFishIntegration;
      shellWrapperName = cfg.shellWrapperName;
    };
  };
}
