# The one definition of how the `homeMod` class is instantiated. The NixOS
# adapter embeds it as a submodule, the standalone path evaluates it on its
# own; both get the same modules and the same arguments (R7).
{ lib, inputs, framework }:
let
  # References are opt-in replacements, never a second automatic Firefox module.
  moduleSet = removeAttrs (framework.modules.discover ../home) [ "firefox-reference" ];

  # R3: the user layer sees host facts, packages, the framework's inputs and
  # whatever the config flake passes as `moduleArgs`. From the system layer it
  # learns one thing: where decrypted secrets appear (null when the host has
  # no secrets backend).
  specialArgs = { pkgs, facts, secretsDirectory ? null, moduleArgs ? { } }:
    moduleArgs // { inherit pkgs facts inputs framework secretsDirectory; };
in
{
  modules = moduleSet;

  submodule = args: lib.types.submoduleWith {
    class = "homeMod";
    specialArgs = specialArgs args;
    modules = lib.attrValues moduleSet;
  };

  eval = { modules ? [ ], ... }@args:
    (lib.evalModules {
      class = "homeMod";
      specialArgs = specialArgs (removeAttrs args [ "modules" ]);
      modules = lib.attrValues moduleSet ++ modules;
    }).config;

  # `files` -> path -> store path. Generated text becomes a store file.
  materialise = pkgs: files:
    lib.mapAttrs
      (path: file:
        if file.text != null then pkgs.writeText (baseNameOf path) file.text else file.source)
      files;
}
