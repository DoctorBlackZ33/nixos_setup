# Neovim built with nvf. The module is only the bridge; editor preferences are
# values and live with the user.
{ config, lib, pkgs, inputs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.nvf;

  editor = inputs.nvf.lib.nvim.neovimConfiguration {
    inherit pkgs;
    modules = [ { config.vim = cfg.settings; } ];
  };
in
{
  options.nvf = {
    enable = lib.mkEnableOption "Neovim built with nvf";

    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "nvf `vim.*` options.";
    };

    package = mkOption {
      type = types.nullOr types.package;
      default = editor.neovim;
      defaultText = lib.literalExpression "the nvf build of `nvf.settings`";
      description = "Editor package; null when it is installed elsewhere.";
    };
  };

  config = lib.mkIf cfg.enable {
    packages = lib.optional (cfg.package != null) cfg.package;
  };
}
