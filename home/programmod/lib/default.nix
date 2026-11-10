lib:
lib.extend (final: prev: {
  programmod = rec {
    dag = import ./dag.nix { lib = final; };
    types = import ./types.nix { lib = final; };

    mkProgramOptions = { name, package ? null }:
      {
        enable = final.mkEnableOption name;

        package = final.mkOption {
          type = final.types.nullOr final.types.package;
          default = package;
          description = "Package for ${name}; set to null when installed outside programmod.";
        };

        settings = final.mkOption {
          type = final.types.attrsOf final.types.anything;
          default = { };
          description = "Program-specific settings.";
        };

        sections = final.mkOption {
          type = types.dagOf final.types.lines;
          default = { };
          description = "Ordered configuration sections.";
        };
      };

    renderSections = { sections, comment ? null }:
      dag.resolveDag {
        name = "sections";
        dag = sections;
        mapResult = final.concatMapStringsSep "\n" (section:
          (if comment == null then "" else "${comment} SECTION: ${section.name}\n") + section.data
        );
      };
  };
})
