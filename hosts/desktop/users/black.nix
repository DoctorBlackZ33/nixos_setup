# Desktop-specific user override (homeMod class).
{ lib, ... }:
{
  hyprland.floatingToggleChord = "SUPER + SPACE";
  hyprland.fragments = lib.mkAfter [ ../../common/hypr-vm.lua ];

  quickshell.clockPrecision = "SystemClock.Seconds";
  quickshell.clockFormat = "yyyy-MM-dd HH:mm:ss";
  quickshell.label = "desktop";
}
