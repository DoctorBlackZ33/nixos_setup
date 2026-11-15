# Named, ordered text sections for formats without a structured generator
# (Lua, fish, QML). A section can be replaced or disabled by name; `order`
# uses the same scale as `lib.mkOrder`. Structured formats use typed
# `settings` with `pkgs.formats` instead.
{ lib }:
let
  inherit (lib) mkOption types;

  order = {
    early = 250;
    before = 500;
    default = 1000;
    after = 1500;
    late = 2000;
  };

  type = types.attrsOf (types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Set to false to drop this section, for example from a host override.";
      };
      order = mkOption {
        type = types.int;
        default = order.default;
        description = "Ascending position; ties are broken by section name.";
      };
      text = mkOption {
        type = types.lines;
        description = "Finished text of this section.";
      };
    };
  });
in
{
  inherit order type;

  option = description: mkOption {
    inherit type description;
    default = { };
  };

  render = { sections, comment ? null }:
    lib.concatMapStringsSep "\n\n"
      (section:
        lib.optionalString (comment != null) "${comment} SECTION: ${section.name}\n"
        + section.text)
      (lib.sortOn (section: section.order)
        (lib.mapAttrsToList (name: section: section // { inherit name; })
          (lib.filterAttrs (_: section: section.enable) sections)));
}
