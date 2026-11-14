-- Shared keyboard bindings.

hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + D", hl.dsp.exec_cmd("fuzzel"))
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + M", hl.dsp.exec_cmd("hyprctl dispatch exit"))
hl.bind("SUPER + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen"))

for index = 1, 10 do
  hl.bind("SUPER + " .. tostring(index % 10), hl.dsp.focus({ workspace = index }))
  hl.bind("SUPER + SHIFT + " .. tostring(index % 10), hl.dsp.window.move({ workspace = index }))
end
