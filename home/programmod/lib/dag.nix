{ lib }:
let
  entryBetween = before: after: data: { inherit data before after; };
  entryAnywhere = entryBetween [ ] [ ];
  entryAfter = after: entryBetween [ ] after;
  entryBefore = before: entryBetween before [ ];

  isEntry = value: value ? data && value ? after && value ? before;

  topoSort = dag:
    let
      entries = builtins.mapAttrs (_: value:
        if isEntry value then value else entryAnywhere value
      ) dag;
      wantedBy = name: builtins.attrNames (lib.filterAttrs (_: entry: builtins.elem name entry.before) entries);
      nodes = lib.mapAttrsToList (name: entry: {
        inherit name;
        inherit (entry) data;
        after = entry.after ++ wantedBy name;
      }) entries;
      sorted = lib.toposort (before: after: builtins.elem before.name after.after) nodes;
    in
    if sorted ? result then
      { result = map (node: { inherit (node) name data; }) sorted.result; }
    else
      sorted;

  resolveDag = { name, dag, mapResult }:
    let
      sorted = topoSort dag;
    in
    if sorted ? result then
      mapResult sorted.result
    else
      abort "Dependency cycle in ${name}: ${builtins.toJSON (map (node: lib.removeAttrs node [ "data" ]) sorted.loops)}";
in
{
  inherit entryAnywhere entryAfter entryBefore entryBetween isEntry topoSort resolveDag;
}
