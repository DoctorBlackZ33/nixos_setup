{ config, inputs, withSystem, ... }:

let
  modules = config.flake.modules.programmod;
  programmod = import ../home/programmod {
    lib = inputs.nixpkgs.lib;
  };
in {
  flake.programmodConfigurations = {
    "black@desktop" = withSystem "x86_64-linux" ({ pkgs, ... }:
      programmod.configuration {
        inherit pkgs;
        modules = [
          { _module.args.nvf = inputs.nvf; }
          modules.user-black
          modules.policy-desktop
        ];
      });

    "black@laptop" = withSystem "x86_64-linux" ({ pkgs, ... }:
      programmod.configuration {
        inherit pkgs;
        modules = [
          { _module.args.nvf = inputs.nvf; }
          modules.user-black
          modules.policy-laptop
        ];
      });
  };

  perSystem = { pkgs, ... }: {
    packages = {
      programmod-configDir-black-desktop =
        config.flake.programmodConfigurations."black@desktop".build.configDir;
      programmod-configDir-black-laptop =
        config.flake.programmodConfigurations."black@laptop".build.configDir;

      programmod-packages-black-desktop = pkgs.buildEnv {
        name = "programmod-packages-black-desktop";
        paths = config.flake.programmodConfigurations."black@desktop".packages;
      };
      programmod-packages-black-laptop = pkgs.buildEnv {
        name = "programmod-packages-black-laptop";
        paths = config.flake.programmodConfigurations."black@laptop".packages;
      };
    };
  };
}
