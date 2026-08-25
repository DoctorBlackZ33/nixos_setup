{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.neovim;
in {
  options.myHome.neovim = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Neovim for this home profile.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim.enable = true;
  };
}
