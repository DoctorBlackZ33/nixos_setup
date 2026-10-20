{ config, lib, ... }: 
let
  cfg = config.homeMod.git;
in {
  options.homeMod.git = {
    enable = lib.mkEnableOption "Enables git";
  };

  config = lib.mkIf cfg.enable {
    programs.git.enable = true;
  };
}
