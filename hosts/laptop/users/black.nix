# Laptop-specific user override (homeMod class).
{ lib, ... }:
{
  hyprland.floatingToggleChord = "SUPER + V";
  hyprland.fragments = lib.mkAfter [ ../../common/hypr-vm.lua ];

  quickshell.clockPrecision = "SystemClock.Minutes";
  quickshell.clockFormat = "yyyy-MM-dd HH:mm";
  quickshell.label = "laptop";
}
