{ config, lib, ... }:
let
  cfg = config.homeMod.lazygit;
in 
{
  options.homeMod.lazygit.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Lazygit.";
  };

  config = lib.mkIf cfg.enable {
    programs.enable = true;
  };
}
