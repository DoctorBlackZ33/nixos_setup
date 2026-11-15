# The single table of capability kinds. Contract types, request merging and
# reconcile are derived from it: adding a kind is one entry here plus a
# provider module under framework/system.
{ lib }:
let
  inherit (lib) mkOption types;
in
{
  kinds = {
    services = {
      label = "service";
      description = "System services that must be running, for example `services.pipewire = { };`.";
      parameters = { };
    };

    pam = {
      label = "PAM service";
      description = "PAM services the user authenticates through, for example `pam.hyprlock = { };`.";
      parameters = { };
    };

    portals = {
      label = "portal";
      description = "XDG desktop portal backends by short name, for example `portals.gtk = { };`.";
      parameters = { };
    };

    secrets = {
      label = "secret";
      description = "Secrets by name. Modules receive a runtime path, never the value.";
      parameters = {
        mode = mkOption {
          type = types.strMatching "[0-7]{4}";
          default = "0400";
          description = "File mode of the decrypted secret.";
        };
      };
    };
  };
}
