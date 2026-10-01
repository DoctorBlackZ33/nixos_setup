{ config, inputs, withSystem, ... }:

let
  modules = config.flake.modules.homeManager;
in {
  flake.homeConfigurations = {
    "black@desktop" = withSystem "x86_64-linux" ({ pkgs, ... }:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          modules.home-black
          modules.preferences-black
          modules.sources-black
          modules.policy-desktop
        ];
      });

    "black@laptop" = withSystem "x86_64-linux" ({ pkgs, ... }:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          modules.home-black
          modules.preferences-black
          modules.sources-black
          modules.policy-laptop
        ];
      });
  };
}
