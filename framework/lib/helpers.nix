{ lib }:
let
  inherit (lib) mkOption types;

  sectionType = types.attrsOf (types.submodule {
    options = {
      order = mkOption {
        type = types.int;
        default = 1000;
        description = "Sections are emitted in ascending order, ties broken by section name.";
      };
      text = mkOption {
        type = types.lines;
        description = "Finished configuration text for this section.";
      };
    };
  });

  orderedSections = sections:
    lib.sortOn (section: section.order)
      (lib.mapAttrsToList (name: section: section // { inherit name; }) sections);

  renderSections = { sections, comment ? null }:
    lib.concatMapStringsSep "\n\n"
      (section:
        lib.optionalString (comment != null) "${comment} SECTION: ${section.name}\n"
        + section.text)
      (orderedSections sections);
in
{
  inherit sectionType renderSections;

  # Conventional section orders shared by the program modules so that sections
  # contributed by different modules keep a deterministic relationship.
  orders = {
    settings = 100;
    defaults = 100;
    environment = 200;
    integrations = 300;
    policy = 700;
    startup = 800;
  };

  mkProgramOptions = { name, package ? null }: {
    enable = lib.mkEnableOption name;
    package = mkOption {
      type = types.nullOr types.package;
      default = package;
      description = "Package for ${name}; null when the host installs it.";
    };
    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Structured settings rendered by this module.";
    };
    sections = mkOption {
      type = sectionType;
      default = { };
      description = "Ordered text sections merged from all definitions.";
    };
  };
}
