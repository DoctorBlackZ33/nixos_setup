{ config, inputs, ... }:

let
  modules = config.flake.modules.nixos;
  homeModules = config.flake.modules.programmod;

  userModule = policy: {
    hjem.users.black = {
      user = "black";
      directory = "/home/black";
      homeMod = {
        _module.args.nvf = inputs.nvf;
        imports = [
          homeModules.user-black
          policy
        ];
      };
    };
  };

  hostModules = host: policy: [
    inputs.hjem.nixosModules.default
    host
    modules.account-black
    modules.kernel-stock
    modules.programmod-adapter
    (userModule policy)
  ];
in {
  flake.nixosConfigurations = {
    desktop = inputs.nixpkgs.lib.nixosSystem {
      modules = hostModules modules.host-desktop homeModules.policy-desktop;
    };

    laptop = inputs.nixpkgs.lib.nixosSystem {
      modules = hostModules modules.host-laptop homeModules.policy-laptop;
    };
  };
}
