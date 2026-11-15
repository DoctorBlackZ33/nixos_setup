# Provider for `services.pipewire`.
{ config, lib, ... }:
let
  inherit (config.contract) facts wanted;
  cfg = config.sysMod.audio;
in
{
  options.sysMod.audio.enable = lib.mkOption {
    type = lib.types.bool;
    default = facts.kind == "workstation";
    defaultText = lib.literalExpression "true on workstations";
    description = "Whether this host offers audio when it is requested.";
  };

  config = lib.mkMerge [
    {
      contract.provides.services.pipewire = config.services.pipewire.enable;
    }

    (lib.mkIf (cfg.enable && wanted.services ? pipewire) {
      # Without rtkit the audio threads lose realtime scheduling under load.
      security.rtkit.enable = true;

      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
        wireplumber.enable = true;
      };
    })
  ];
}
