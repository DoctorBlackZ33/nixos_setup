{
  config,
  lib,
  ...
}: let
  cfg = config.myHome.direnv;
in {
  options.myHome.direnv = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable direnv for this home profile.";
    };

    nixDirenv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable nix-direnv integration.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = cfg.nixDirenv;
    };
  };
}
