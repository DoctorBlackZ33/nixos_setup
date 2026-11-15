# The one place that turns a directory into a module set, so flake outputs,
# adapters and checks cannot disagree about which modules exist.
{ lib }:
{
  # name -> path for every `*.nix` file directly inside `directory`.
  discover = directory:
    lib.mapAttrs'
      (file: _: lib.nameValuePair (lib.removeSuffix ".nix" file) (directory + "/${file}"))
      (lib.filterAttrs
        (file: type: type == "regular" && lib.hasSuffix ".nix" file)
        (builtins.readDir directory));
}
