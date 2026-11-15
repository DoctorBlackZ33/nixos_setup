# Provider for the graphical session: compositors and desktop portals. A host
# that does not offer it leaves the request unmet, so a desktop user placed on
# a server fails the contract instead of turning the server into a desktop.
{ config, lib, pkgs, ... }:
let
  inherit (config.contract) facts wanted;
  cfg = config.sysMod.desktop;

  wants = kind: name: cfg.enable && builtins.hasAttr name wanted.${kind};

  compositor = wants "services" "hyprland" || wants "services" "niri";

  portalPackages = {
    hyprland = pkgs.xdg-desktop-portal-hyprland;
    gtk = pkgs.xdg-desktop-portal-gtk;
    gnome = pkgs.xdg-desktop-portal-gnome;
  };
  wantedPortals = lib.filter (wants "portals") (lib.attrNames portalPackages);

  # Only a backend that is installed may be the default.
  fallback = if lib.elem "gtk" wantedPortals then [ "gtk" ] else lib.take 1 wantedPortals;
in
{
  options.sysMod.desktop.enable = lib.mkOption {
    type = lib.types.bool;
    default = facts.kind == "workstation";
    defaultText = lib.literalExpression "true on workstations";
    description = "Whether this host offers a graphical session (compositor, portals) when one is requested.";
  };

  config = lib.mkMerge [
    {
      contract.provides = {
        services.hyprland = config.programs.hyprland.enable;
        services.niri = config.programs.niri.enable;
        portals = lib.mapAttrs
          (_: package: config.xdg.portal.enable && lib.elem package config.xdg.portal.extraPortals)
          portalPackages;
      };
    }

    (lib.mkIf (wants "services" "hyprland") {
      programs.hyprland = {
        enable = true;
        xwayland.enable = true;
      };
    })

    (lib.mkIf (wants "services" "niri") {
      programs.niri.enable = true;
    })

    (lib.mkIf compositor {
      hardware.graphics.enable = true;

      # A session without fonts renders boxes. Which fonts is the host's
      # choice; this is only nixpkgs' own baseline.
      fonts.enableDefaultPackages = lib.mkDefault true;
    })

    (lib.mkIf (wantedPortals != [ ]) {
      xdg.portal = {
        enable = true;
        extraPortals = map (name: portalPackages.${name}) wantedPortals;
        config = lib.mkMerge [
          { common.default = fallback; }
          # The gtk portal cannot capture the screen on Hyprland.
          (lib.mkIf (lib.elem "hyprland" wantedPortals) {
            hyprland = {
              default = fallback;
              "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
              "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
            };
          })
        ];
      };
    })
  ];
}
