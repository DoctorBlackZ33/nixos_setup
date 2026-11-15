# What black's session looks like on this host only (homeMod class).
{ lib, ... }:
{
  hyprland.floatingToggleChord = "SUPER + SPACE";
  hyprland.fragments = lib.mkAfter [ ../../common/hypr-vm.lua ];

  quickshell.clockPrecision = "Seconds";
  quickshell.clockFormat = "yyyy-MM-dd HH:mm:ss";
  quickshell.label = "desktop";
}
