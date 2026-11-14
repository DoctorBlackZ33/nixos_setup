# Deployments: which users run on which host, through which adapter.
{ config, inputs, lib, ... }:
let
  framework = inputs.framework.framework;
  nixpkgsLib = inputs.nixpkgs.lib;
  standaloneAdapter = import framework.adapters.standalone { lib = nixpkgsLib; };

  userConf = user: ./users + "/${user}/default.nix";
  hostConf = host: ./hosts + "/${host}/default.nix";
  hostFacts = host: import (./hosts + "/${host}/facts.nix");
  hostUserOverride = host: user: ./hosts + "/${host}/users/${user}.nix";

  systemModules = lib.attrValues framework.systemModules;

  targets = {
    desktop = {
      host = "desktop";
      users = [ "black" ];
      adapter = "nixos";
    };
    laptop = {
      host = "laptop";
      users = [ "black" ];
      adapter = "nixos";
    };
  };

  mkUser = host: user: {
    hjem.users.${user} = {
      user = user;
      directory = "/home/${user}";
      homeMod = {
        imports = [
          (userConf user)
          (hostUserOverride host user)
        ];
      };
    };
  };

  mkNixos = target: nixpkgsLib.nixosSystem {
    modules = [
      inputs.hjem.nixosModules.default
      framework.adapters.nixos
      (hostConf target.host)
      { hjem.specialArgs.nvf = inputs.nvf; }
    ]
    ++ systemModules
    ++ map (mkUser target.host) target.users;
  };

  standaloneModules = host: user: [
    (userConf user)
    (hostUserOverride host user)
  ];

  mkStandalonePackages = pkgs: lib.concatMapAttrs
    (name: target:
      let
        info = hostFacts target.host;
      in
      lib.concatMapAttrs
        (user: _:
          let
            configuration = standaloneAdapter.mkConfiguration {
              inherit pkgs;
              facts = info.facts;
              provides = info.provides;
              modules = standaloneModules target.host user;
              specialArgs = { nvf = inputs.nvf; };
            };
          in
          {
            "${user}@${name}" = configuration.build.configDir;
            "${user}@${name}-packages" = configuration.build.packagesEnv;
            "${user}@${name}-env" = configuration.build.loadEnv;
          })
        (lib.genAttrs target.users (_: null)))
    targets;
in
{
  flake.nixosConfigurations =
    lib.mapAttrs (_: mkNixos)
      (lib.filterAttrs (_: target: target.adapter == "nixos") targets);

  perSystem = { pkgs, ... }: {
    packages = mkStandalonePackages pkgs;

    formatter = pkgs.alejandra;

    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        alejandra
        git
        nil
        nixd
      ];
    };
  };
}
