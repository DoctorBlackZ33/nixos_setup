{
  config,
  lib,
  ...
}: {
  options.myHome.homeManager.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the Home Manager command-line tool.";
  };

  config = lib.mkIf config.myHome.homeManager.enable {
    programs.home-manager.enable = true;
  };
}
