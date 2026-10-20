{config, lib, ... }:
let
  cfg = config.homeMod.zoxide;
in
{
  options.homeMod.zoxide = {
    enable = lib.mkEnableOption "enable zoxide home module";
    
  };
}
