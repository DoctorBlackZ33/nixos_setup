# Standalone adapter: evaluates the same homeMod modules without NixOS and
# turns the result into a config tree plus an environment script. Provides come
# from the host declaration (standalone targets cannot introspect their OS).
{ lib }:
let
  contract = import ../lib/contract.nix { inherit lib; };
  reconcileLib = import ../lib/reconcile.nix { inherit lib; };

  homeModuleFiles = builtins.filter (path: lib.hasSuffix ".nix" (toString path))
    (lib.mapAttrsToList (name: _: ../home + "/${name}") (builtins.readDir ../home));
in
{
  mkConfiguration = { pkgs, facts, modules, provides ? contract.emptyProvides, specialArgs ? { } }:
    let
      homeMod = (lib.evalModules {
        class = "homeMod";
        specialArgs = { inherit facts pkgs; } // specialArgs;
        modules = homeModuleFiles ++ modules;
      }).config;

      result = reconcileLib.reconcile { requires = homeMod.requires; inherit provides facts; };

      files = lib.mapAttrs
        (path: file: if file.text != null then pkgs.writeText (baseNameOf path) file.text else file.source)
        homeMod.files;

      configDir = pkgs.linkFarm "home-${facts.hostName}-config"
        (lib.mapAttrsToList (path: source: { name = path; path = source; }) files);

      loadEnv = pkgs.writeShellScript "home-${facts.hostName}-env"
        (lib.concatMapStringsSep "\n"
          (name: "export ${name}=${lib.escapeShellArg homeMod.environment.${name}}")
          (builtins.attrNames homeMod.environment));

      packagesEnv = pkgs.buildEnv {
        name = "home-${facts.hostName}-packages";
        paths = homeMod.packages;
      };
    in
    if result.errors != [ ]
    then
      throw (lib.concatStringsSep "\n" (
        [ "homeMod contract violations for '${facts.hostName}':" ]
        ++ map (error: "  - ${error}") result.errors
      ))
    else
    {
      config = homeMod;
      inherit (result) warnings;
      build = {
        inherit files configDir loadEnv packagesEnv;
      };
    };
}
