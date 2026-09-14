-- VM device values intentionally load last and override shared defaults.

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = 1,
})
hl.config({
  general = {
    gaps_in = 5,
    gaps_out = 10,
  },
})

-- Hyprland exposes reload (not a literal restart dispatcher); reload the
-- configuration while preserving the running compositor instance.
hl.bind("SUPER + X", hl.dsp.exec_cmd("hyprctl reload"))
