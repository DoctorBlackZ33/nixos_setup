{...}: {
  myHome.neovim.pluginGroups = ["core" "coding" "content" "workflow"];

  myHome.hyprland = {
    monitors = [",preferred,auto,1"];
    innerGaps = 5;
    outerGaps = 10;
  };

  myHome.quickshell = {
    enable = true;
    autostart = false;
    activeConfig = "vm";
    barHeight = 30;
    background = "#181825";
    foreground = "#cdd6f4";
    label = "nixos-dev";
  };
}
