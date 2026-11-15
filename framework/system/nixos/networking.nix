{ config, lib, ... }:
let
  cfg = config.sysMod.networking;
in
{
  options.sysMod.networking.backend = lib.mkOption {
    type = lib.types.enum [ "networkmanager" "networkd" ];
    default = if config.contract.facts.kind == "workstation" then "networkmanager" else "networkd";
    defaultText = lib.literalExpression ''"networkmanager" on workstations, "networkd" on servers'';
    description = "Which service configures the network.";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.backend == "networkmanager") {
      networking.networkmanager.enable = true;
    })
    (lib.mkIf (cfg.backend == "networkd") {
      networking.useNetworkd = true;
    })
  ];
}
