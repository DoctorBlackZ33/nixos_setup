# A check made of named conditions. It is decided during evaluation, so
# `nix flake check --no-build` runs it, and a failure lists the conditions that
# broke. The derivation is an empty marker.
{ lib }:
pkgs: name: conditions:
let
  failed = lib.attrNames (lib.filterAttrs (_: holds: !holds) conditions);
in
assert lib.assertMsg (failed == [ ]) "check '${name}' failed: ${lib.concatStringsSep "; " failed}";
pkgs.runCommand "check-${name}" { } "touch $out"
