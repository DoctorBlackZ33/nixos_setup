{ config, lib, ... }: 
{
  options.homeMod.homeManager.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the Home Manager command-line tool.";
  };

  config = lib.mkIf config.homeMod.homeManager.enable {
    programs.home-manager.enable = true;
  };
}
