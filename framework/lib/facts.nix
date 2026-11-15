# Host facts as every adapter sees them: one typed value, built from the
# hand-written `facts.nix` and, when present, the nixos-facter report.
{ lib, framework }:
let
  # PCI vendor id (decimal, as nixos-facter reports it) -> fact value.
  gpuVendors = {
    "4098" = "amd";
    "32902" = "intel";
    "4318" = "nvidia";
    "6900" = "virtual"; # virtio
    "4660" = "virtual"; # QEMU standard VGA
    "6966" = "virtual"; # QXL
    "5549" = "virtual"; # VMware
    "33006" = "virtual"; # VirtualBox
    "4115" = "virtual"; # Cirrus
  };

  # With several cards the discrete one decides.
  gpuPreference = [ "nvidia" "amd" "intel" "virtual" ];

  # The preferred mode of one monitor, with its refresh rate when the report
  # lists that mode.
  display = monitor:
    let
      detail = monitor.detail or { };
      mode = lib.findFirst
        (resource:
          (resource.type or null) == "monitor"
          && (resource.width or null) == detail.width
          && (resource.height or null) == detail.height
          && resource ? vertical_frequency)
        null
        (monitor.resources or [ ]);
    in
    lib.optional (detail ? width && detail ? height) (
      { inherit (detail) width height; }
      // lib.optionalAttrs (mode != null) { refresh = mode.vertical_frequency; }
    );

  # report -> the subset of facts hardware detection can know. Missing keys
  # stay undefined rather than becoming guesses.
  fromFacter = report:
    let
      hardware = report.hardware or { };
      vendors = map
        (card: gpuVendors.${toString (card.vendor.value or "")} or null)
        (hardware.graphics_card or [ ]);
      virtualisation = report.virtualisation or "none";
    in
    lib.filterAttrsRecursive (_: value: value != null) {
      platform = report.system or null;
      virtualisation = if virtualisation == "none" then null else virtualisation;
      gpu.vendor = lib.findFirst (vendor: lib.elem vendor vendors) null gpuPreference;
      displays = lib.concatMap display (hardware.monitor or [ ]);
    };
in
{
  inherit fromFacter;

  # Hand-written facts win over detected ones; `name` is the inventory key.
  resolve = { name, facts, report ? null }:
    framework.contract.evalFacts (
      lib.optional (report != null) (lib.mapAttrsRecursive (_: lib.mkDefault) (fromFacter report))
      ++ [
        facts
        { inherit name; }
      ]
    );
}
