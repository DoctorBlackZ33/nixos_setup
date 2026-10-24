{
  config,
  lib,
  pkgs,
  ...
}: {
  options.myHome.desktopTools.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable desktop utility applications.";
  };

  config = lib.mkIf config.myHome.desktopTools.enable {
    home.packages = with pkgs; [
      grim
      kitty
      wl-clipboard
    ];
  };
}
