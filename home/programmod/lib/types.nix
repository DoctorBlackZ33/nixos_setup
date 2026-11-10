{ lib }:
let
  inherit (lib) mkOption mkOptionType types;
  inherit (lib.programmod) dag;

  dagEntryOf = elemType:
    let
      entryModule = types.submodule {
        options = {
          data = mkOption { type = elemType; };
          after = mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
          before = mkOption {
            type = types.listOf types.str;
            default = [ ];
          };
        };
      };
      asEntry = definition: definition // {
        value =
          if dag.isEntry definition.value then
            definition.value
          else
            dag.entryAnywhere definition.value;
      };
    in
    mkOptionType {
      name = "dagEntryOf";
      description = "DAG entry of ${elemType.description}";
      merge = loc: definitions: entryModule.merge loc (map asEntry definitions);
    };

  dagOf = elemType: types.attrsOf (dagEntryOf elemType);
in
{
  inherit dagOf dagEntryOf;
}
