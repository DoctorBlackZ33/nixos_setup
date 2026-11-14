# NixOS adapter: imports the user layer, fulfils the union of requirements,
# computes what the system provides and wires reconcile into assertions and
# warnings.
#
# Every definition below is a lazy option value. Nothing in the definition set
# forces `config` (hjem users carry `osConfig = config`), which would recurse
# while the module system collects definitions.
{ config, lib, pkgs, ... }:
let
  contract = import ../lib/contract.nix { inherit lib; };
  reconcileLib = import ../lib/reconcile.nix { inherit lib; };

  userRequires = map (user: user.homeMod.requires)
    (lib.filter (user: user.enable) (lib.attrValues config.hjem.users));
  mergedRequires = lib.foldl' contract.mergeRequires config.requires userRequires;

  facts = config.facts;

  portalPackages = {
    hyprland = pkgs.xdg-desktop-portal-hyprland;
    gtk = pkgs.xdg-desktop-portal-gtk;
    gnome = pkgs.xdg-desktop-portal-gnome;
  };

  requestedPortals = mergedRequires.portals;
  knownPortals = lib.filter (name: builtins.hasAttr name portalPackages) requestedPortals;

  hasService = name: builtins.hasAttr name mergedRequires.services;
  hasPortal = name: builtins.elem name requestedPortals;

  # Capability -> the option the host reports as provided.
  serviceOptions = {
    hyprland = config.programs.hyprland.enable;
    niri = config.programs.niri.enable;
    pipewire = config.services.pipewire.enable;
    openssh = config.services.openssh.enable;
    greetd = config.services.greetd.enable;
    qemu-guest = config.services.qemuGuest.enable;
  };

  provides = {
    pam = lib.genAttrs (lib.attrNames config.security.pam.services) (_: true);
    portals = lib.filter
      (name: lib.elem portalPackages.${name} config.xdg.portal.extraPortals)
      (lib.attrNames portalPackages);
    services = serviceOptions;
    setuid = lib.mapAttrs (_: wrapper: wrapper.setuid or false) config.security.wrappers;
    # NixOS cannot introspect udev rule strings or secret material, so these two
    # namespaces come from the host declaration.
    udev.rules = config.provides.udev.rules;
    secrets = config.provides.secrets;
  };

  result = reconcileLib.reconcile { requires = mergedRequires; inherit provides facts; };
in
{
  imports = [
    ./contract.nix
    ./hjem-register.nix
  ];

  config = {
    homeModRequires = mergedRequires;

    programs.hyprland = lib.mkIf (hasService "hyprland") {
      enable = true;
      xwayland.enable = true;
    };

    programs.niri.enable = lib.mkIf (hasService "niri") true;

    security.rtkit.enable = lib.mkIf (hasService "pipewire") true;
    services.pipewire = lib.mkIf (hasService "pipewire") {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    services.openssh.enable = lib.mkIf (hasService "openssh") true;
    services.greetd.enable = lib.mkIf (hasService "greetd") true;
    services.qemuGuest.enable = lib.mkIf (hasService "qemu-guest") true;

    security.pam.services =
      lib.mkIf (mergedRequires.pam != { })
        (lib.genAttrs (lib.attrNames mergedRequires.pam) (_: { }));

    xdg.portal = lib.mkIf (requestedPortals != [ ]) {
      enable = true;
      extraPortals = lib.unique (map (name: portalPackages.${name}) knownPortals);
      config = lib.mkMerge [
        { common.default = [ "gtk" ]; }
        (lib.mkIf (hasPortal "hyprland") {
          hyprland = {
            default = [ "gtk" ];
            "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
            "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
          };
        })
      ];
    };

    # Kept behind mkIf: `lib.optional` would force reconcile (and therefore
    # the user layer) while the definition set is still being collected.
    assertions = lib.mkIf (result.errors != [ ]) [
      {
        assertion = false;
        message = lib.concatStringsSep "\n" (
          [ "homeMod/systemMod contract violations on '${facts.hostName}':" ]
          ++ map (error: "  - ${error}") result.errors
        );
      }
    ];

    warnings = result.warnings;
  };
}
