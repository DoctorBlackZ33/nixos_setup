{ config, lib, ... }:

{
  options.myHome.customCommands.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable shared shell convenience commands.";
  };

  config = lib.mkIf config.myHome.customCommands.enable {
    programs.fish.shellAliases = {
      ll = "ls -lah";
      la = "ls -A";
    };
  };
}
