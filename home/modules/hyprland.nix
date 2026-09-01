{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.hyprland;
in {
  options.myHome.hyprland = {
    enable = lib.mkEnableOption "the shared Hyprland desktop configuration" // {
      default = true;
    };
    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [",preferred,auto,1"];
      description = "Hyprland monitor descriptions.";
    };
    innerGaps = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Hyprland inner window gap.";
    };
    outerGaps = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Hyprland outer window gap.";
    };
    extraBinds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional Hyprland binds.";
    };
    extraWindowRules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional Hyprland window rules.";
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      configType = "hyprlang";
      settings = {
        "$terminal" = "kitty";
        "$menu" = "fuzzel";
        monitor = cfg.monitors;
        input = {
          kb_layout = "us";
          follow_mouse = 1;
          sensitivity = 0;
        };
        general = {
          gaps_in = cfg.innerGaps;
          gaps_out = cfg.outerGaps;
          border_size = 2;
          layout = "dwindle";
          allow_tearing = false;
        };
        decoration = {
          rounding = 8;
          blur.enabled = false;
        };
        animations.enabled = false;
        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
        };
        "exec-once" = ["waybar" "mako"];
        bind = [
          "SUPER, RETURN, exec, $terminal"
          "SUPER, D, exec, $menu"
          "SUPER, Q, killactive"
          "SUPER, M, exit"
          "SUPER, F, fullscreen"
          "SUPER, V, togglefloating"
          "SUPER, 1, workspace, 1"
          "SUPER, 2, workspace, 2"
          "SUPER, 3, workspace, 3"
          "SUPER SHIFT, 1, movetoworkspace, 1"
          "SUPER SHIFT, 2, movetoworkspace, 2"
          "SUPER SHIFT, 3, movetoworkspace, 3"
        ] ++ cfg.extraBinds;
        windowrule = cfg.extraWindowRules;
      };
    };
  };
}
