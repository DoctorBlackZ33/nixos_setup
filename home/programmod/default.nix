{ lib }:
let
  programmodLib = import ./lib lib;
  isNix = path: lib.hasSuffix ".nix" (toString path);
  programModules = lib.concatMap (name:
    let
      path = ./programs + "/${name}";
    in
    if lib.filesystem.pathIsDirectory path then
      builtins.filter isNix (lib.filesystem.listFilesRecursive path)
    else
      lib.optional (isNix path) path
  ) (builtins.attrNames (builtins.readDir ./programs));
  baseModules = [ ./core.nix ] ++ programModules;
  specialArgsFor = pkgs: {
    inherit pkgs;
    lib = programmodLib;
  };
in
{
  inherit baseModules;
  lib = programmodLib;

  configuration = { pkgs, modules ? [ ] }:
    (programmodLib.evalModules {
      class = "programmod";
      specialArgs = specialArgsFor pkgs;
      modules = baseModules ++ modules;
    }).config;

  submoduleFor = pkgs:
    programmodLib.types.submoduleWith {
      class = "programmod";
      specialArgs = specialArgsFor pkgs;
      modules = baseModules;
    };
}
