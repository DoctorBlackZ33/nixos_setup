#This code comes from opus 5.5, it is reviewed and understood
/*
args@ works the same as inputs@ in flake.nix, its a binding and argument check.
first it makes everything available locally like inherit, since all arguments are roots here there is not much purpose to that
then it binds all those input to itself so we can later call args ? osConfig 
to ask about the inputs of the function that this module represents
lastly it forces config and lib to be part of the input which is again trivial here
*/
args@{ config, lib, ... }:
let
  cfg = config.homeMod.hyprland;
  # makes types = lib.types and mkOption = lib.mkOption in local scope
  inherit (lib) types mkOption;
in {
  options.homeMod.hyprland = {
    enable = lib.mkEnableOption "Hyprland config";
    settings = mkOption {
      /*
      the types.attrsOf can be read as attribute set with elements of type ... so anything here
      anything according to opus is here to not have a pkgs dependency on a lua format which is quite nice
      */
      type = types.attrsOf types.anything; 
      default = { }; 
    };
    sections = mkOption {
      /*
      this is the same attrsOf idea but instead every element is of type submodule
      this means everything is part of a named submodule for example (hjem.users.black.homeMod.hyprland.windowrules)
      this named submodlue then has to contain an order oriented on the mkBefore and mkAfter ordering
      the options.text is just multiline strings, in this module this should be lua
      the text should be finished lua so use ${} one can use ${lib.generators.toLua { multiline = false; } cfg.something}
      to not worry about string escaping ect inside lua, the finished text then gets turned into a file bellow
      */
      type = types.attrsOf (types.submodule {
        options.order = mkOption { type = types.int; default = 1000; };
        options.text  = mkOption { type = types.lines; };
      });
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      /*
      args ? osConfig is save and the second half doesn't get called and errors if its false because its not NixOS
      thus standalone application is still safe as the check just fails, such package installation needs to be handled elsewhere
      */
      assertion = !(args ? osConfig) || args.osConfig.programs.hyprland.enable;
      message = "homeMod.hyprland needs programs.hyprland.enable on the NixOS side";
    }];
    # just pass the local settings to a section to simplify the config file generation
    homeMod.hyprland.sections.settings = lib.mkIf (cfg.settings != { }) {
      order = 100;
      text = "local settings = ${lib.generators.toLua { } cfg.settings}";
    };
    /*
    lib.attrValues discards the submodule names and turns sections into {order; text;}
    that then is sorted by order and then by text in canonical order
    lastly everything is concatinated with newlines and put into a hyprland.lua linked via hjem xdg.config.files syntax
    */
    xdg.config.files."hypr/hyprland.lua".text =
      lib.concatMapStringsSep "\n\n" (s: s.text)
        (lib.sortOn (s: s.order) (lib.attrValues cfg.sections));
  };
}
