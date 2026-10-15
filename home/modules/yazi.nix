{ config, lib, ... }:
let
  cfg = config.homeMod.yazi;
in
{
  options.homeMod.yazi = {
    enable = lib.mkEnableOption "enable yazi home module";
    
    shell_integration = lib.mkOption {
      type = lib.types.nullOr [ "fish" ];
      default = null;
      example = "fish";
      description = "Choose with which shell yazi should interact, enables things like navigation via yazi";
    }
    
    
    
  }
}
