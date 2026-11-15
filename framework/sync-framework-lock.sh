# Forward the complete root input graph, including transitive pins. Nix prunes
# inputs the framework does not use; verify corresponding paths with the same
# pure comparison used by checks.config.

cd "$(git rev-parse --show-toplevel)"

status=0
(cd framework && nix flake lock --reference-lock-file ../flake.lock --output-lock-file flake.lock) || status=$?

unreconciled=$(nix eval --impure --json --expr '
  (import ./framework/lib/lock-drift.nix {
    rootLock = builtins.fromJSON (builtins.readFile ./flake.lock);
    frameworkLock = builtins.fromJSON (builtins.readFile ./framework/flake.lock);
  }).drifted
' | jq -r '.[]')

if [ -n "$unreconciled" ]; then
  printf 'sync-framework-lock: could not reconcile these framework input paths with flake.lock:\n%s\n' "$unreconciled" >&2
  exit 1
fi

exit "$status"
