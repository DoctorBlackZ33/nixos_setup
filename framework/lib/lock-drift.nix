# Compare dependency paths, not node names or an unordered set of pins.
# Follows paths start at each lock's root; node references are lock-local IDs.
{ rootLock, frameworkLock }:
let
  inputsOf = node: node.inputs or { };
  resolve = lock: reference:
    if builtins.isString reference then reference else
      builtins.foldl'
        (node: name: resolve lock (inputsOf lock.nodes.${node}).${name})
        lock.root reference;

  # Local trees are not external pins; their relative paths can differ between
  # the two flake roots. Their input edges are still compared below.
  pinOf = node:
    if (node.locked.type or null) == "path" then { type = "path"; }
    else node.locked or null;

  compare = seen: path: rootId: frameworkId:
    let
      pair = { inherit rootId frameworkId; };
      rootNode = rootLock.nodes.${rootId};
      frameworkNode = frameworkLock.nodes.${frameworkId};
      rootInputs = inputsOf rootNode;
      frameworkInputs = inputsOf frameworkNode;
      names = builtins.attrNames (rootInputs // frameworkInputs);
    in
    if builtins.elem pair seen then [ ]
    else if pinOf rootNode != pinOf frameworkNode
      || (rootNode.flake or true) != (frameworkNode.flake or true) then
      [ (builtins.concatStringsSep "/" path) ]
    else builtins.concatLists (map
      (name:
        let childPath = path ++ [ name ]; in
        if !(rootInputs ? ${name} && frameworkInputs ? ${name}) then
          [ (builtins.concatStringsSep "/" childPath) ]
        else compare (seen ++ [ pair ]) childPath
          (resolve rootLock rootInputs.${name})
          (resolve frameworkLock frameworkInputs.${name}))
      names);

  rootInputs = inputsOf rootLock.nodes.${rootLock.root};
  frameworkInputs = inputsOf frameworkLock.nodes.${frameworkLock.root};
in
{
  # Resolve a dependency path from the root to its lock-local node ID.
  resolvePath = path: resolve rootLock path;

  drifted = builtins.concatLists (map
    (name:
      if !(rootInputs ? ${name}) then [ name ]
      else compare [ ] [ name ]
        (resolve rootLock rootInputs.${name})
        (resolve frameworkLock frameworkInputs.${name}))
    (builtins.attrNames frameworkInputs));
}
