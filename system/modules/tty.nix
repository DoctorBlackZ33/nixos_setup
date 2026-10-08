{ config, lib, pkgs, ... }:
let
  cfg = config.sysMod.tty;
  /*
  gemini suggested this to avoid problems with unset compositors, instead of handling different greetd start commands
  we set the compositor before and set the start command argument accordingly and pass that to the tuigreetcmd
  then we need a null check and fall back to dynamic wayland discovery if unspecified 
  compositor should never be unspecified or null due to an assertion in desktop.nix but if it is not imported at all
  this could still happen as the assertion would never be run if nobody imports sysMod-desktop.
  */
  compositor = config.sysMod.desktop.compositor or null;
  launchCmd =
    if compositor == "hyprland" then "start-hyprland" # or "Hyprland"
    else if compositor == "niri" then "niri-session"
    else "";
  tuigreetCmd =
    if launchCmd != null then
      "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${launchCmd}"
    else
      "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-user-session --sessions /run/current-system/sw/share/wayland-sessions";
in
{
  options.sysMod.tty = {
    # purposefully no enable option, its there by default, you can only change the settings
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "Europe/Zurich";
      description = "Set the timezone for the machine";
    };
    defaultLocale = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "Sets the default locale, for adding additional locales see sysMod.tty.additionalLocales for adding alternative locales";
    };
    
    extraLocales = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = "[ \"en_US.UTF-8/UTF-8\" ]";
      description = "Adds additional locales to the system, see sysMod.tty.defaultLocale for setting the default";
    };
    /*
    greetd is a login manager, SDDM is a display manager. Display Manager like Window Manager are dated terms
    used in the X11 era that do not translate to Wayland. SDDM and greetd do the same thing essentially but SDDM
    does way more as X11 required display management too, greetd just creates login sessions as Wayland does not need this.
    */
    greeter = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "greetd" "SDDM" ]);
      default = null;
      example = "greetd";
      description = "The login manager or display manager to use.";
    };
  };

  config = {
    
    time.timeZone = cfg.timeZone;
    i18n.defaultLocale = cfg.defaultLocale;
    i18n.additionalLocales = cfg.additionalLocales;
    console.useXkbConfig = true;
    
    services.greetd = lib.mkIf (cfg.greeter == "greetd") {
      enable = true;
      settings.default_session = {
        user = "greeter";
        command = tuigreetCmd;
      };
    };

    services.displayManager.sddm = lib.mkIf (cfg.greeter == "SDDM") {
      enable = true;
      wayland.enable = true;
    };
  };
}
