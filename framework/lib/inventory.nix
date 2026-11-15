# Schema of `deployments.nix`. Field names follow clan's inventory where they
# overlap, so a later move is mechanical; what a host *is* stays in its facts.
{ lib }:
let
  inherit (lib) mkOption types;

  type = types.attrsOf (types.submodule {
    options = {
      host = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Directory under `hosts/`. Defaults to the deployment name.";
      };
      users = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Directories under `users/` deployed to this host. May be empty.";
      };
      homes = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = { root = "/root"; };
        description = "Home directories that are not `/home/<user>`, for standalone delivery.";
      };
    };
  });
in
{
  inherit type;

  # Plain data -> typed inventory, for callers outside a module system.
  eval = deployments:
    (lib.evalModules {
      modules = [
        { options.deployments = mkOption { inherit type; }; }
        { inherit deployments; }
      ];
    }).config.deployments;
}
