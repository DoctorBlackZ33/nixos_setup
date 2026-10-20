{ config, lib, ... }:
let
  fish = config.homeMod.fish;
in 
{
  options.homeMod.customCommands.enable = lib.mkOption {
    type = lib.mkEnableOption "Enable shared shell convenience commands.";
  };

  config = lib.mkIf config.homeMod.customCommands.enable {
    # placeholder for shared config
  } // (lib.optionalAttrs  fish.enable {
      programs.fish.shellAliases = {
        ll = "ls -lah";
        la = "ls -A";
      };
    });
}
