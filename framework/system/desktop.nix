# Desktop hardware and font policy. It activates itself only when some user
# asks for a graphical capability, so the same module set serves servers.
{ config, lib, pkgs, ... }:
let
  gui = config.homeModRequires.portals != [ ];
in
{
  config = lib.mkIf gui {
    hardware.graphics.enable = true;

    fonts.packages = with pkgs; [
      dejavu_fonts
      liberation_ttf
      noto-fonts
      noto-fonts-color-emoji
    ];
  };
}
