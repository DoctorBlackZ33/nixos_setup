# Nix and flake-parts reference

## 1. Nix expression lookup

### Lexical forms

| Form | Meaning / exact rule | Minimal example |
|---|---|---|
| `# comment` / `/* comment */` | Line / nested block comment; whitespace is otherwise insignificant. | `x = 1; # note` |
| `name` | Identifier: starts with a letter or `_`; subsequent characters may include letters, digits, `_`, `'`, `-`. Keywords (`let`, `in`, `if`, `then`, `else`, `with`, `rec`, `assert`, `or`) are not identifiers in keyword positions. | `my-value` |
| `a.b.c` | Attribute path; selection is lazy and errors if a selected attribute is absent. Quote a non-identifier key. | `pkgs.hello`; `x."a-b"` |
| `"a-b" = v;` / `${expr} = v;` | Quoted / interpolated attribute name in a set. `${expr}` must evaluate to a string or coercible value. | `{ "x-y" = 1; }` |
| `42`, `-3`, `true`, `false`, `null` | Integer, unary-negated integer, booleans, null. | `enabled = true;` |
| `"text ${expr}"` | Double-quoted string; `${...}` interpolation is evaluated and coerced to a string. `\n`, `\t`, `\"`, `\\` are escapes. | `"system = ${system}"` |
| `''text ${expr}''` | Indented (multi-line) string; common indentation is stripped; interpolation works. Escape interpolation as `''${...}`. | `text = ''\n  line\n'';` |
| `/absolute/file`, `./relative/file`, `../parent/file` | Path literal; relative paths resolve relative to the file containing the expression and are copied/content-addressed when used as a flake input. | `./home/programmod/programs/git.nix` |
| `https://...`, `git+https://...`, `github:owner/repo` | URI-like literals are accepted in contexts that expect a URI; quote them in attr values for unambiguous strings. Flake refs use the URI grammar in §3. | `nixpkgs.url = "...";` |
| `<name/path>` | Angle-bracket path searched through `NIX_PATH`; impure and unavailable in pure flake evaluation unless supplied. | `import <nixpkgs> {}` |
| `[ e1 e2 ]` | List; elements are separated by whitespace, not commas. Elements are lazy. | `[ pkgs.git pkgs.jq ]` |
| `{ a = e; b = e; }` | Attribute set; bindings require semicolons. Attribute values are lazy. | `{ enable = true; }` |
| `rec { a = 1; b = a + 1; }` | Recursive set; bindings may refer to sibling bindings in the same set. Plain sets cannot self-reference. | `rec { a = 1; b = a + 1; }` |
| `let b = e; c = e; in body` | Lexically binds names; all bindings are visible in `body` and mutually visible within the `let`; semicolons terminate bindings. | `let x = 2; in x * 3` |
| `with set; body` | Adds `set` attributes to lexical lookup for `body`; does not copy or merge the set. Nested `with` can hide names; explicit `set.name` is clearer. | `with pkgs; [ git jq ]` |
| `inherit x y;` / `inherit (set) x y;` | Shorthand binding: `inherit x` means `x = x`; parenthesized form takes names from another expression. | `let inherit (pkgs) git jq; in git` |
| `f arg` | Function application; whitespace separates function and argument; application is left-associative. | `(x: x + 1) 4` |

### Functions, patterns, control

| Form | Semantics |
|---|---|
| `x: body` | Unary function. Functions are first-class and lazy; use `f x` to apply. Multi-argument functions are curried (`a: b: a + b`). |
| `{ a, b }: body` | Attribute-set pattern; caller must provide `a` and `b` and no unknown attributes unless `...` is present. |
| `{ a, b ? default, ... }:` | `?` supplies a value only when the named argument is absent; `...` accepts extra attributes without binding them. Defaults are lazy. |
| `args@{ a, b ? 1, ... }: body` | Named pattern binding: `args` receives the complete argument set while `a`/`b` are destructured. |
| `f { a = 1; }` | Attribute-set argument is one value; braces do not mean multiple positional arguments. |
| `if cond then yes else no` | Only the selected branch is evaluated. `cond` must be a boolean. |
| `assert cond; expr` | Checks `cond` before evaluating `expr`; throws if false. Common in module definitions and derivation metadata. |
| `throw "message"` / `abort "message"` | `throw` raises an evaluation error; `abort` terminates evaluation immediately. Neither returns a value. |
| `attrs.key or fallback` | Attribute-selection fallback (not boolean OR): evaluates `fallback` only if `key` is absent. For dynamic keys use `attrs ? key`. |
| `builtins.hasAttr name attrs` | Explicit attribute existence test; `attrs ? name` is the concise form. |

### Operators and precedence (high to low)

| Precedence | Operators / form | Meaning and distinction |
|---:|---|---|
| 1 | `f x` | Function application; left-associative. Parenthesize a function expression when needed. |
| 2 | `a.b`, `a."key"`, `a ? key` | Attribute selection / existence test. Selection does not deep-merge sets. |
| 3 | `!x`, `-x` | Boolean negation / numeric negation. |
| 4 | `*`, `/` | Numeric multiplication / division. |
| 5 | `+`, `-` | Numeric arithmetic; `+` also concatenates strings and supports path/string coercion where defined. |
| 6 | `++` | List concatenation only; unlike `//`, it does not merge attributes. |
| 7 | `==`, `!=` | Equality / inequality; comparison is lazy where possible. |
| 8 | `<`, `>`, `<=`, `>=` | Ordering comparison. |
| 9 | `&&` | Boolean AND; right side short-circuits. |
| 10 | `||` | Boolean OR; right side short-circuits. |
| 11 | `//` | Shallow attribute-set update: keys on the right win; nested sets are replaced, not recursively merged. `lib.recursiveUpdate` is a separate deep-merge operation. |
| 12 | `->` | Boolean implication (`a -> b` is equivalent to `!a || b`); right side is lazy. |
| 13 | `or` | Attribute-selection fallback syntax; use only after a selection such as `set.key or default`. |

Use parentheses around mixed arithmetic, list concatenation, updates, and conditionals; e.g. `((base // override) // extra)` and `if ok then (a ++ b) else []`. `=` is a set/`let` binding delimiter, `:` introduces a function, and `;` terminates a binding or expression statement; none is an assignment operator.

### Evaluation, imports, derivations, purity

| Topic | Lookup |
|---|---|
| Laziness | Nix uses call-by-need: a binding/list element/attribute is evaluated only when demanded, then shared. A set can be constructed without evaluating every value; `builtins.deepSeq` forces a whole value before returning another. |
| `import path` | Reads and evaluates a Nix file; the result may be any Nix value, commonly a function (`import ./module.nix args`) or set. Relative paths resolve relative to the importing file. `import <nixpkgs>` depends on `NIX_PATH`; flake code should use the locked `inputs.nixpkgs` instead. |
| Derivation | A derivation is a lazy recipe/value (usually from `pkgs.stdenv.mkDerivation`); evaluation creates a `.drv` plan, while realization (`nix build`, a system switch, or a dependency demand) executes it and produces store paths. A derivation is an attr set with `type = "derivation"`. |
| Evaluation vs build | Evaluation computes the expression/output graph and may fetch/evaluate source inputs; realization builds derivations; activation performs system/home side effects. `nix eval` usually does not realize derivations, but import-from-derivation (used by this repository's TOML settings) can build a generator during evaluation; `nix build` does not activate. |
| Purity | Flake evaluation is locked and normally pure: undeclared filesystem/network/environment dependencies are rejected or ignored. `--impure` permits ambient values such as `NIX_PATH` and environment variables. `builtins.pathExists` can inspect declared/local paths; a path source can be copied into the store, while `mkOutOfStoreSymlink` intentionally keeps a live filesystem path. |
| String vs path | A path literal carries source-location semantics and is eligible for store copying; a string containing `/home/black/experimental/...` is only text. Convert deliberately with `toString`/`builtins.toPath` where supported. |
| Module file vs module value | `./x.nix` is a path value; `imports = [ ./x.nix ]` asks the module system to import it. A module value can instead be `{ config, lib, ... }: { ... }`. |

## 2. Flakes and command-line lookup

### Flake reference and output selection

| Form | Interpretation |
|---|---|
| `path:/home/black/experimental` | Explicit local flake URI; avoids ambiguity with a bare path. |
| `path:/home/black/experimental#nixosConfigurations.desktop` | URI plus `#` attribute selector; selectors traverse attributes with dots. Quote selectors containing `@`, spaces, or shell metacharacters. |
| `path:./framework` | Relative path input (`inputs.framework.url`). Nix copies the subdirectory as a path flake, so its files must be git-tracked. |
| `github:owner/repo` / `github:owner/repo/ref` | GitHub shorthand; `ref` can be branch, tag, or revision. |
| `./.` / `path:.` | Local flake path; lock metadata records a content hash/mtime and dirty-tree status as applicable. |
| `#attr` | Output selector shorthand when the flake URI is supplied separately. In shell, quote `path:/home/black/experimental#packages.x86_64-linux."black@desktop"`. |

Standard output conventions: `packages.<system>.<name>` (buildable packages), `apps.<system>.<name>` (runnable apps), `devShells.<system>.<name>`, `checks.<system>.<name>`, `formatter.<system>`, and `templates`. This repository additionally exposes `nixosConfigurations` and the framework flake exposes a custom `framework` output (`lib`, `homeModules`, `systemModules`, `adapters`); `nix flake check` warns that `framework` is an unknown output name, which is expected.

### Evaluation, realization, activation

| Stage | What happens | Commands here |
|---|---|---|
| Evaluation | Parse/evaluate `flake.nix`, locked inputs, modules, and selected output; errors are type/option/assert/import failures. | `nix flake show`, `nix flake metadata`, `nix eval`, `nix flake check --no-build` |
| Realization | Build selected derivation and dependencies into `/nix/store`; no system switch. | `nix build`; `nixos-rebuild build` |
| Activation | Run generated activation logic and change the running system or user home. | `sudo nixos-rebuild switch --flake 'path:/home/black/experimental#desktop'` (use `#laptop` for the other host; applies its Hjem-managed user configuration). |

### Commands and flags used in this repository

| Command / flag | Effect |
|---|---|
| `nix flake show URI` | Summarizes recognized outputs; `framework` appears as an unknown output. |
| `nix flake metadata URI` | Shows locked URI, fingerprint, and input revisions without switching. |
| `nix flake check --no-build URI` | Evaluates check derivations without building them. Framework checks fail at evaluation time; the config check forces both toplevels, all contract assertions and standalone outputs. |
| `nix eval URI#attr --apply builtins.attrNames` | Evaluates an attr set and prints its keys; use `--json` for machine-readable output. |
| `nix build --no-link URI#attr` | Realizes a derivation without making `./result`; omit `--no-link` to create a result symlink. |
| `--no-update-lock-file` | Refuses lock-file updates. |
| `--no-write-lock-file` | Does not write a generated lock file; use with read-only inspection/builds. |
| `--flake URI` | Select a flake and NixOS output with `nixos-rebuild`. |

Copy-paste queries for the current architecture:

```sh
F='path:/home/black/experimental'

nix flake show --no-update-lock-file --no-write-lock-file "$F"
nix flake metadata --no-update-lock-file --no-write-lock-file "$F"

nix eval --json --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations" --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  "$F#packages.x86_64-linux" --apply builtins.attrNames

nix eval --raw --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations.desktop.config.networking.hostName"
nix eval --json --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations.desktop.config.homeModRequires"
nix eval --json --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations.desktop.config.provides"
nix eval --json --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations.desktop.config.assertions" --apply 'xs: builtins.filter (x: !x.assertion) xs'
nix eval --json --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations.desktop.config.warnings"

nix eval --raw --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations.desktop.config.hjem.users.black.homeMod.files.\"hypr/hyprland.lua\".text"
nix eval --raw --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations.laptop.config.hjem.users.black.homeMod.files.\"quickshell/black/DesktopPolicy.qml\".text"
```

Build hosts and standalone outputs without activation or lock writes:

```sh
nix build --no-link --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations.desktop.config.system.build.toplevel"
nix build --no-link --no-update-lock-file --no-write-lock-file \
  "$F#nixosConfigurations.laptop.config.system.build.toplevel"
nix build --no-link --no-update-lock-file --no-write-lock-file \
  "$F#packages.x86_64-linux.\"black@desktop\""
nix build --no-link --no-update-lock-file --no-write-lock-file \
  "$F#packages.x86_64-linux.\"black@desktop-packages\""
nix build --no-link --no-update-lock-file --no-write-lock-file \
  "$F#packages.x86_64-linux.\"black@desktop-env\""
```

Framework checks (reconcile fixtures, contract types, home module evaluation):

```sh
nix flake check --no-build 'path:/home/black/experimental/framework'
```

`checks.x86_64-linux.*` derivations there are empty; the assertions run during
evaluation, so a broken fixture fails `nix flake check` with the case name.

## 3. flake-parts semantics

### Module scopes and arguments

`flake-parts.lib.mkFlake { inherit inputs; } module` runs a Nix module system whose final `config.flake` becomes flake outputs. `config` and `options` are the flake-parts module-system state, not NixOS, Hjem, or homeMod state.

| Scope | Common module arguments | What `config` means | What this repo uses |
|---|---|---|---|
| Top-level flake-parts module | `config`, `options`, `lib`, `inputs`, `self`, `getSystem`, `moduleWithSystem`, `withSystem`; `system`/`pkgs` are not generally available here. | Global flake-parts options, including `config.flake` and `config.perSystem`. | `deployments.nix` and `checks.nix` in the config flake; `checks/default.nix` in the framework flake. |
| `perSystem = { system, pkgs, ... }: { ... }` | `system`, `pkgs`, `self'`, `inputs'`, plus module `config`/`lib`; only explicitly named function parameters are passed. | The current system's per-system option namespace. | Standalone packages, formatter, devShell, and check derivations. |
| NixOS module | `config`, `options`, `lib`, `pkgs`, `modulesPath`, and declared special args. | NixOS option tree. | hostConf, framework system modules, the NixOS adapter. |
| Hjem user module | `config`, `options`, `lib`, `pkgs`, `osConfig`, `osOptions`, `hjem-lib`, `utils`. | Hjem user options plus the nested `homeMod` option. | `framework/adapters/hjem.nix`, which declares the `homeMod` class. |
| homeMod module | `config`, `options`, `lib`, special args `pkgs`, `facts`. | homeMod options: `files`, `packages`, `environment`, `requires`, and program options. | `framework/home/*.nix`, `users/<user>`, `hosts/<host>/users/<user>.nix`. |

`inputs` is the root input set; `self` is the final flake output set. `withSystem` bridges a top-level output to `pkgs` for a system; this repository builds standalone packages in `perSystem` instead.

### Options, definitions, imports, and priorities

| Construct | Exact role |
|---|---|
| `options.<path> = lib.mkOption { type; default; description; };` | Declares an option schema. |
| `config.<path> = value;` | Defines an option; definitions merge through the option type. |
| `lib.mkDefault` / `lib.mkForce` / `lib.mkOverride n` | Change definition priority. Host role values use plain definitions; shared defaults use `mkDefault`. |
| `lib.mkIf condition { ... }` | Delays conditional definitions; the condition is forced when the option merges, not while definitions are collected. Use this for anything derived from `config` (see the adapter note in section 4). |
| `lib.mkAfter` / `lib.mkBefore` | Raise/lower list-definition priority; the host Hyprland fragment is appended with `lib.mkAfter`. |
| `imports = [ module-or-path ... ];` | Recursively imports modules before option/config merging. |
| `flake.<output> = value;` | Defines a top-level flake output; the framework flake's `framework` attribute is a plain value, not a transposed per-system option. |

Two failure modes hit this repository and are worth remembering:

- **Fixed-point cycles.** Hjem builds the `users` option type from `hjem.extraModules`. A module that both sets `hjem.extraModules` and reads `config.hjem.users` creates a cycle that silently degrades to the empty default. Registration therefore lives in `framework/adapters/hjem-register.nix`, separate from the adapter that reads users.
- **Eager forcing in definition sets.** `lib.optional cond value` forces `cond` while definitions are collected. `assertions = lib.optional (result.errors != [ ]) …` therefore recursed; it is written as `lib.mkIf (result.errors != [ ]) [ … ]` instead.

## 4. This repository: graph and data flow

### Root and input graph

`/home/black/experimental/flake.nix` declares these locked inputs:

| Input | URL / relation | Consumers |
|---|---|---|
| `nixpkgs` | pinned NixOS 26.05 nar | NixOS systems, Hjem, standalone packages, framework checks via follows |
| `hjem` | `github:feel-co/hjem`; follows `nixpkgs` | `hjem.nixosModules.default` and the user layer |
| `nvf` | `github:NotAShelf/nvf`; follows root `nixpkgs` | `homeMod.nvf` via `_module` arg from the deployment |
| `framework` | `path:./framework`; `nixpkgs` and `flake-parts` follow the root inputs | homeMod/systemMod modules, contract, reconcile, adapters |
| `flake-parts` | `github:hercules-ci/flake-parts` | `mkFlake` in both flakes |

The framework flake pins its own `nixpkgs` for standalone checks; the config
flake overrides it with `follows`. Because `framework` is a path input, every
file under `framework/` must be git-tracked before evaluation.

### Framework outputs

`inputs.framework.framework` is a plain attrset:

| Key | Contents |
|---|---|
| `lib.contract` | `{ lib }:` function returning `requiresType`, `providesType`, `factsType`, `emptyRequires`, `emptyProvides`, `normaliseRequires`, `mergeRequires`. |
| `lib.reconcile` | `{ lib }:` function returning `reconcile { requires, provides, facts; }` and `factValue`. |
| `lib.helpers` | section type/renderer, `mkProgramOptions`, conventional section orders. |
| `homeModules` | name → path: `core`, `hyprland`, `fish`, `git`, `gh`, `direnv`, `yazi`, `zoxide`, `fuzzel`, `mako`, `quickshell`, `nvf`. |
| `systemModules` | name → path: `base`, `nix-settings`, `development`, `networking`, `desktop`, `locale`, `greeter`, `accounts`. |
| `adapters` | `contract` (facts/provides/requires options), `hjem-register`, `hjem` (user module), `nixos`, `standalone` (function). |

The NixOS adapter imports every framework home module into the `homeMod`
submodule; adding `framework/home/<program>.nix` is enough for it to be
available to users (still gated by its `enable` option).

### data flow

1. `deployments.nix` maps a target to hostConf, the framework module set and
   one homeMod composition per user.
2. Each user's `homeMod` evaluates framework home modules + `users/<user>` +
   `hosts/<host>/users/<user>.nix` with `facts` and `pkgs` as special args.
3. The NixOS adapter unions `config.requires` (systemMod) with each enabled
   user's `homeMod.requires`, fulfils known capabilities, computes `provides`
   from the resulting NixOS config, and reconciles.
4. reconcile errors become a single failing assertion; warnings become
   `config.warnings`. `config.homeModRequires` exposes the union read-only so
   system modules can gate themselves (the desktop module enables graphics and
   fonts only when a user requires a portal).
5. Hjem receives `homeMod.files` as `xdg.config.files`, `packages` as user
   packages, and `environment` as `environment.sessionVariables`.

### Policy values and outputs

Role differences are pure values in `hosts/<host>/users/black.nix`:

| Value | desktop | laptop |
|---|---|---|
| `hyprland.floatingToggleChord` | `SUPER + SPACE` | `SUPER + V` |
| `quickshell.clockPrecision` | `SystemClock.Seconds` | `SystemClock.Minutes` |
| `quickshell.clockFormat` | `yyyy-MM-dd HH:mm:ss` | `yyyy-MM-dd HH:mm` |
| `quickshell.label` | `desktop` | `laptop` |

Both hosts append `hosts/common/hypr-vm.lua` with `lib.mkAfter`. The generated
`hypr/hyprland.lua` contains the sections `settings` (from
`hyprland.settings` via `lib.generators.toLua`), `sources` (`dofile` lines for
`hyprland.fragments`), `policy` (the floating-toggle binding) and `startup`
(`hl.on("hyprland.start", …)` for `hyprland.startupCommands`), in that order.

`hosts/<host>/facts.nix` is pure data: typed `facts` plus declared `provides`.
The NixOS adapter uses its computed provides for reconciliation; the standalone
adapter reconciles against the declared values, because it cannot introspect
the target OS.

### Source boundaries

- `framework/`: general modules, contract, reconcile, adapters, checks.
- `users/black/`: user-owned Hyprland fragments, Quickshell tree and user
  settings, plus profiles and preferences.
- `hosts/common/`: shared VM hardware and host values.
- `hosts/<host>/`: facts, host values, role-specific user override.
- `deployments.nix` and `checks.nix`: output composition and evaluation
  checks only; no configuration values.

### Verification performed

- `nix flake check --no-build path:/home/black/experimental/framework`: seven
  evaluation-time checks pass (reconcile clean/required/optional, contract
  types, home modules, Hyprland rendering and ordering, other rendering).
- `nix flake check --no-build path:/home/black/experimental`: both deployments
  evaluate, all contract assertions hold, standalone outputs derive.
- `nix build` of `nixosConfigurations.{desktop,laptop}.config.system.build.toplevel`
  and of `packages.x86_64-linux."black@desktop"{,-packages,-env}` succeeds.
- No switch or activation was run.

## 5. Further reference

- [Vimjoyer Nix index](https://www.vimjoyer.com/nix): compact examples for flakes, flake-parts, shells, and dendritic module layouts; examples here are adapted only as cross-reference, while repository paths and behavior above are independently verified.
