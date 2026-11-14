# Config checks: every deployment must evaluate, pass its contract assertions
# and produce a toplevel / config tree derivation. Evaluation is the check.
{ config, lib, ... }:
{
  perSystem = { pkgs, ... }:
    let
      hosts = config.flake.nixosConfigurations;
      hostNames = lib.attrNames hosts;

      evaluated = map (name: hosts.${name}.config) hostNames;

      assertionsHold = lib.all
        (hostConfig: lib.all (assertion: assertion.assertion) hostConfig.assertions)
        evaluated;

      hostNamesSet = lib.all (hostConfig: hostConfig.networking.hostName != "") evaluated;

      toplevels = map (hostConfig: hostConfig.system.build.toplevel.drvPath) evaluated;

      standalonePackages = config.flake.packages.x86_64-linux or { };
      standaloneNames = lib.filter
        (name: lib.hasInfix "@" name && !(lib.hasSuffix "-packages" name) && !(lib.hasSuffix "-env" name))
        (lib.attrNames standalonePackages);
      standaloneTrees = map (name: standalonePackages.${name}.drvPath) standaloneNames;
    in
    {
      checks.deployments =
        assert lib.assertMsg (hostNames == [ "desktop" "laptop" ]) "expected the desktop and laptop hosts";
        assert lib.assertMsg assertionsHold "a host has failing contract assertions";
        assert lib.assertMsg hostNamesSet "a host has an empty hostName";
        assert lib.assertMsg (lib.all (path: lib.isString path) toplevels) "a host produced no toplevel";
        assert lib.assertMsg (standaloneNames != [ ]) "no standalone configurations were produced";
        assert lib.assertMsg (lib.all (path: lib.isString path) standaloneTrees) "a standalone config tree was not derivable";
        pkgs.runCommand "check-deployments" { } "touch $out";
    };
}
