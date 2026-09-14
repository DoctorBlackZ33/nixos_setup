-- Shared Hyprland input, general, layout, and decoration defaults.

hl.config({
  input = {
    kb_layout = "us",
    follow_mouse = 1,
    sensitivity = 0,
  },
  general = {
    border_size = 2,
    layout = "dwindle",
    allow_tearing = false,
  },
  decoration = {
    rounding = 8,
    blur = {
      enabled = false,
    },
  },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },
})
