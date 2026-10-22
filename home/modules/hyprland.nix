{ config, lib, ... }:
let
  cfg = config.homeMod.hyprland;
in 
{
  options.homeMod.hyprland = {
    # dont do: enable = lib.mkEnableOption "Enable Hyprland and its config generation";
    renderers = lib.mkOption {
      /*
      This is the renderers, its an attribute set that contains arbitrary strings as keys and 
      lambda functions that output multi-line strings as values
      so something like the following could this set be:
      {
        featureX = rendererX: {some lua code with string placeholders}
        featureY = rendererY: {some lua code with string placeholders}
      }
      and then a feature could have some hyprland options with
      options.homeMod.hyprland.featureX = {enable; settingX.1; settingX.2;} 
      and a config that passes a renderer to homeMod.hyprland.renderers.featureX
      this renderer just contains a function with lua file and string parsing to parse the options at the right place
      */
      type = lib.types.attrsOf (lib.types.functionTo lib.types.lines);
      default = {};
      internal = true; 
      description = "Renderer interface of type attrSet of lambda functions with return type multi-line strings for hyprland config generation";
    };
  };
  config = lib.mkIf cfg.enable {
    programs.hyprland.enable = true;
    /*
    This now actually parses that renderers attribute set first the mapAttrsToList is evaluated:
    first cfg.renderers gets parsed and arranged into an alphabetiaclly ordererd list (beware of this when needing order in settings),
    _name is the arbitrary string key from the set for example featureX
    renderer is the actual value lambda function that takes the settings attribute set as input
    the renderer cfg now actually calls that unpacked function on config.homeMod.hyprland which contains our renderers set
    this means each renderer function in the features needs to evaluates its template from config.homeMod.feature and
    parse it into a file with the values replaced, the function then returns that multi-line string (type = lib.types.lines).
    after that entire set is flattened into a list.
    the concatStringsSep just concatinates all those lua strings into the config file and then links that file to the nix store
    */
    xdg.configFile."hypr/hyprland.lua".text =
      lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList (_name: renderer: renderer cfg) 
        cfg.renderers) + "\n";
  };
}
