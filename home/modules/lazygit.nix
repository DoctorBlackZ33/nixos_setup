{ config, lib, pkgs, ... }:

{
  options.myHome.lazygit.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Lazygit.";
  };

  config = lib.mkIf config.myHome.lazygit.enable {
    home.packages = [ pkgs.lazygit ];
  };
}
