# A desktop user who gates her graphical session on the host kind.
{ lib, facts, ... }:
{
  config = lib.mkMerge [
    {
      fish.enable = true;
      fish.aliases.ll = "ls -lah";
      git.enable = true;
      git.settings.user.name = "Alice";
      environment.EDITOR = "vi";
    }

    (lib.mkIf (facts.kind == "workstation") {
      hyprland.enable = true;
      hyprland.settings.general.gaps_in = 5;
      hyprland.fragments = [ ./session.lua ];
      hyprland.startupCommands = [ "quickshell --config alice" ];
      quickshell.enable = true;
      quickshell.activeConfig = "alice";
      fuzzel.enable = true;
      mako.enable = true;
    })
  ];
}
