{ config, lib, ... }:
let
  anyUser = f: lib.any (user: user.enable && f user.homeMod) (lib.attrValues config.hjem.users);
in
{
  hjem.extraModules = [ ./hjem.nix ];

  programs.hyprland.enable = lib.mkDefault (anyUser (homeMod: homeMod.hyprland.enable));
}
