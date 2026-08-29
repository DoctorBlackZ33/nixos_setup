{ config, lib, ... }: let
  cfg = config.myHome.<name>;
in {
  options.myHome.<name>.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable the <name> Home Manager module.";
  };

  config = lib.mkIf cfg.enable {
  };
}
