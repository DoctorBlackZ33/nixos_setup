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
| `github:owner/repo` / `github:owner/repo/ref` | GitHub shorthand; `ref` can be branch, tag, or revision. |
| `git+https://host/repo?ref=main&rev=...` | Explicit Git transport and query parameters; `rev` pins content, `ref` names the requested ref. |
| `./.` / `path:.` | Local flake path; lock metadata records a content hash/mtime and dirty-tree status as applicable. |
| `#attr` | Output selector shorthand when the flake URI is supplied separately. In shell, quote `path:/home/black/experimental#programmodConfigurations."black@desktop".build.configDir`. |

Standard output conventions: `packages.<system>.<name>` (buildable packages), `apps.<system>.<name>` (runnable apps), `devShells.<system>.<name>`, `checks.<system>.<name>`, `formatter.<system>`, and `templates`. This repository additionally exposes `nixosConfigurations`, `programmodConfigurations`, and flake-parts registries under `modules`; these are valid custom attrs, while the configDir and package-environment entries are standard buildable packages.

### Evaluation, realization, activation

| Stage | What happens | Commands here |
|---|---|---|
| Evaluation | Parse/evaluate `flake.nix`, locked inputs, modules, and selected output; errors are type/option/assert/import failures. | `nix flake show`, `nix flake metadata`, `nix eval`, `nix flake check --no-build` |
| Realization | Build selected derivation and dependencies into `/nix/store`; no system/home switch. | `nixos-rebuild build`; `nix build` |
| Activation | Run generated activation logic and change the running system or user home. | `sudo nixos-rebuild switch --flake 'path:/home/black/experimental#desktop'` (use `#laptop` for the other host; applies its Hjem-managed user configuration). |

### Commands and flags used in this repository

| Command / flag | Effect |
|---|---|
| `nix flake show URI` | Summarizes recognized outputs; custom attrs may appear as `unknown`. |
| `nix flake metadata URI` | Shows locked URI, fingerprint, and input revisions without switching. |
| `nix flake check --no-build URI --print-build-logs` | Evaluates checks and module/output consistency without building check outputs; evaluating TOML-backed settings can still require import-from-derivation (IFD). |
| `nix eval URI#attr --apply builtins.attrNames` | Evaluates an attr set and prints its keys; use `--json` for machine-readable output. |
| `nix build --no-link URI#attr` | Realizes a derivation without making `./result`; omit `--no-link` to create a result symlink. |
| `--no-update-lock-file` | Refuses lock-file updates. |
| `--no-write-lock-file` | Does not write a generated lock file; use with read-only inspection/builds. |
| `--flake URI` | Select a flake and NixOS output with `nixos-rebuild`. |
| `--print-build-logs` | Streams build logs when builds are allowed. |
| `--no-build` | Avoids building requested outputs/checks; evaluation may still need IFD to build a generator. |
| `--no-link` | Build without creating a result symlink. |

Copy-paste read-only output queries:

```sh
nix flake show --no-update-lock-file --no-write-lock-file path:/home/black/experimental
nix flake metadata --no-update-lock-file --no-write-lock-file path:/home/black/experimental
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/experimental#nixosConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/experimental#programmodConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/experimental#modules.programmod --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/experimental#modules.nixos --apply builtins.attrNames
```

Build NixOS hosts or standalone programmod outputs without activation or lock writes:

```sh
nixos-rebuild build --flake 'path:/home/black/experimental#desktop' \
  --no-update-lock-file --no-write-lock-file
nixos-rebuild build --flake 'path:/home/black/experimental#laptop' \
  --no-update-lock-file --no-write-lock-file
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#packages.x86_64-linux.programmod-configDir-black-desktop'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#packages.x86_64-linux.programmod-configDir-black-laptop'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#packages.x86_64-linux.programmod-packages-black-desktop'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#packages.x86_64-linux.programmod-packages-black-laptop'
```

Enter the repository's per-system development shell (the `devShells.x86_64-linux.default` output):

```sh
nix develop --no-update-lock-file --no-write-lock-file \
  path:/home/black/experimental
```

The NixOS configuration is the activation boundary: Hjem manages the user's
files, packages, and session variables as part of that host. The standalone
`programmodConfigurations` are configuration data, configDir trees, and
package environments; they have no activation package. This migration did not
run a system switch or any home activation.

Before the first switch, inspect the existing Home Manager generation and
`~/.config` links. Hjem has `clobberByDefault = false`, so old Home
Manager-managed links can block Hjem's first file activation. Retire only
obsolete Home Manager-owned links/generation as appropriate for the previous
deployment; use Home Manager's uninstall workflow only if the old setup was a
standalone Home Manager deployment. Preserve unrelated user files; do not set
`clobberFiles = true` as a blanket workaround.

After reviewing the existing files, the operator can activate either host:

```sh
sudo nixos-rebuild switch --flake 'path:/home/black/experimental#desktop'
sudo nixos-rebuild switch --flake 'path:/home/black/experimental#laptop'
```

These are documented operator commands; neither was run by the assistant.

The standalone configs' `build.loadEnv` and the Hjem adapter's
`environment.sessionVariables` expose the configured environment to their
respective consumers. The Fish program module also emits the shared
`programmod-environment` section with Fish-native `set -gx` lines after the
`settings` section for both standalone and Hjem delivery.

### Programmod self-check

Resolve the flake-locked nixpkgs and Hjem source paths, then evaluate the
spec-compatible `nix-instantiate` entrypoint:

```sh
NIXPKGS_SOURCE="$(nix eval --raw --impure --no-update-lock-file --no-write-lock-file \
  --expr '(builtins.getFlake "/home/black/experimental").inputs.nixpkgs.outPath')"
HJEM_SOURCE="$(nix eval --raw --impure --no-update-lock-file --no-write-lock-file \
  --expr '(builtins.getFlake "/home/black/experimental").inputs.hjem.outPath')"
nix-instantiate --eval --strict home/programmod/test.nix \
  --arg nixpkgs "$NIXPKGS_SOURCE" --arg hjem "$HJEM_SOURCE"
```

It returns `{ ok = true; }` only after its framework, standalone, and actual
NixOS+Hjem adapter assertions succeed.

## 3. flake-parts semantics

### Module scopes and arguments

`flake-parts.lib.mkFlake { inherit inputs; } module` runs a Nix module system whose final `config.flake` becomes flake outputs. `config` and `options` are the flake-parts module-system state, not NixOS, Hjem, or programmod state.

| Scope | Common module arguments | What `config` means | What this repo uses |
|---|---|---|---|
| Top-level flake-parts module | `config`, `options`, `lib`, `inputs`, `self`, `getSystem`, `moduleWithSystem`, `withSystem`; `system`/`pkgs` are not generally available here. | Global flake-parts options, including `config.flake`, `config.perSystem`, `config.systems`, and registries. | All `flake-module.nix` files define registries or outputs here. |
| `perSystem = { system, pkgs, ... }: { ... }` | `system`, `pkgs`, `self'`, `inputs'`, plus module `config`/`lib`; only explicitly named function parameters are passed. | The current system's per-system option namespace. | `system/modules/flake-module.nix` defines `formatter` and `devShells.default`. |
| `withSystem "x86_64-linux" ({ pkgs, system, ... }: expr)` | Per-system context selected explicitly; `pkgs` is the pinned nixpkgs package set for that system. | The selected per-system context while constructing `expr`. | Deployments construct the standalone programmod configurations. |
| NixOS module | `config`, `options`, `lib`, `pkgs`, `modulesPath`, and declared special args. | NixOS option tree (`services`, `boot`, `users`, etc.). | `host-vm-common`, `host-desktop`, `host-laptop`, `system-*`, `kernel-*`, `account-black`, Hjem, and the programmod adapter. |
| Hjem user module | `config`, `options`, `lib`, `pkgs`, and declared special args. | Hjem user options and the nested programmod `homeMod`. | The user path/directory, Hjem adapter, and Hjem-delivered programmod configuration. |

`inputs` is the root input set; `self` is the recursively defined final flake output set. In a per-system scope, `inputs'`/`self'` are system-scoped projections. `withSystem` is the supported bridge from a top-level output definition to `pkgs` and other per-system values; do not assume top-level `pkgs` or `system`.

### Options, definitions, imports, and transposition

| Construct | Exact role |
|---|---|
| `options.foo = lib.mkOption { type; default; description; };` | Declares an option schema. `type` validates and supplies the type-specific merge behavior; `default` is a definition only when no stronger definition exists. |
| `config.foo = value;` | Defines an option. All definitions from imported modules are collected, prioritized, type-checked, and merged; this is not assignment. |
| `lib.mkDefault value` / `lib.mkForce value` / `lib.mkOverride n value` | Change definition priority. `mkForce` is a high-priority override; use sparingly to resolve an intentional conflict. |
| `lib.mkIf condition { ... }` | Delays conditional definitions so option evaluation can merge them without eagerly evaluating a disabled branch. |
| `lib.mkMerge [ { ... } { ... } ]` | Emits multiple definitions from one module for normal option merging. |
| `imports = [ module-or-path ... ];` | Recursively imports modules before option/config merging. Imports add definitions; they do not call a module like an ordinary function. |
| `systems = [ "x86_64-linux" ... ];` | Declares systems for which flake-parts evaluates `perSystem`. This repository has exactly `x86_64-linux`; it does not claim other platforms. |
| `flake.foo = value;` | Defines a top-level flake output attr. Nested attrs such as `flake.nixosConfigurations` and `flake.programmodConfigurations` become outputs verbatim. |
| `perSystem = { ... }: { formatter = ...; devShells.default = ...; };` | Defines system-specific options; flake-parts transposes supported per-system outputs to `formatter.<system>` and `devShells.<system>`. |
| Transposition boundary | Only options declared by flake-parts as per-system options are transposed. Top-level `flake.programmodConfigurations` is not automatically converted to a per-system attr; buildable configDir/package environments are explicitly exposed under `packages.<system>`. |
| `flake.modules.<namespace>.<name> = module;` | With `inputs.flake-parts.flakeModules.modules` imported, registers reusable modules under a named namespace. Registries are ordinary flake attrs and are consumed by later modules through `config.flake.modules`. |

A list option normally concatenates definitions; an attr-set option recursively merges keys; scalar options conflict unless priorities select one. Module merging is distinct from Nix `//`: `//` is a shallow expression-level update, while the module system applies option types, priorities, conditionals, and declarations.

Common flake-parts failure modes: using `pkgs`/`system` at top level instead of `withSystem`/`perSystem`; omitting a module from root `imports`; importing a NixOS module into Hjem or programmod (or vice versa); defining `config` as if it were a plain set rather than option definitions; relying on `//` for a deep module merge; using an unlisted system; creating a cycle where a registry module imports the output that consumes it; and using an unquoted `#`/`@` selector in the shell. A missing option declaration, wrong option type, duplicate scalar definition, or missing attr selection fails during evaluation rather than at activation.

## 4. This repository: graph and data flow

### Root and input graph

`/home/black/experimental/flake.nix` declares these locked inputs:

| Input | URL / relation | Consumers |
|---|---|---|
| `nixpkgs` | `https://releases.nixos.org/nixos/26.05/nixos-26.05.6503.21ea275a7c46/nixexprs.tar.xz` | NixOS systems, Hjem, standalone programmod packages. |
| `hjem` | `github:feel-co/hjem`; follows `nixpkgs` | Hjem NixOS module and per-user configuration. |
| `nvf` | `github:NotAShelf/nvf`; follows root `nixpkgs` | Independent `lib.nvim.neovimConfiguration` used by the `nvf` program module. |
| `nix-cachyos-kernel` | Pinned archive at `dbae8dc454556968710401643aa2c6867d166440.tar.gz` | Retained `kernel-cachy` registry module; neither current host selects it. |
| `flake-parts` | `github:hercules-ci/flake-parts` | `mkFlake` and explicit module registries. |

After changing flake inputs, run `nix flake lock` from
`/home/black/experimental` to update the lock. The root imports the
flake-parts module-registry extension, system registries, the programmod
adapter registry, home profile/policy/user registries, and deployment
constructors. Hjem and the programmod NixOS adapter are imported by both
NixOS host outputs.

### Registries and ownership

| Area | Responsibility |
|---|---|
| `system/modules/flake-module.nix` | Registers shared NixOS base, desktop, development, platform and kernel modules; keeps the formatter and development shell. |
| `system/accounts/` | Registers `account-black`; owns the immutable NixOS login, groups, shell and existing bootstrap password hash. |
| `system/hosts/vm/` | Registers common VM settings and named desktop/laptop hosts. Both use unchanged `hardware.nix`, software-rendering settings and NixOS state version `26.05`; only the hostname differs. |
| `home/programmod/` | Contains the class-`programmod` evaluator/core, Hjem and NixOS adapters, and auto-discovered program modules. Programs generate only programmod files, packages, and environment. |
| `home/profiles/` | Composes base, desktop and development features; package-only utilities are plain packages. |
| `home/users/black/flake-module.nix` | Composes the user's profiles, editor/Git preferences, and sources. The Hjem deployment sets `user = "black"` and `directory = "/home/black"`. |
| `home/users/black/sources.nix` | Centralizes ordered Hyprland fragments, Quickshell file/directory sources and the session startup command. |
| `home/policies/` | Registers role values under `desktopPolicy`: Hyprland floating-toggle chord and Quickshell clock precision, date-time format, and label. |
| `deployments/` | Builds the desktop/laptop NixOS+Hjem hosts and matching standalone programmod configs. |

Entries under `flake.modules` are reusable modules, not runnable outputs.
`deployments/` constructs `nixosConfigurations.*` and
`programmodConfigurations.*`. Each NixOS output imports Hjem and the programmod
NixOS adapter, then evaluates the same user/profile/source modules and its role
policy under `hjem.users.black.homeMod`. The standalone output calls
`programmod.configuration` with those same programmod-class modules and does
not read `osConfig`.

Each standalone config exposes `files`, `packages`, and `environment`, plus
`build.files`, `build.configDir`, and `build.loadEnv`. The configDir output is
a `.config`-shaped package; the package-environment output contains the
standalone config's package list. Neither is an activation generation.

### Policy values and outputs

`desktopPolicy.hyprland.floatingToggleChord` is emitted into exactly one
floating-toggle binding in `.config/hypr/hyprland.lua`. The desktop and laptop
policies set `SUPER + SPACE` and `SUPER + V`, respectively.

`desktopPolicy.quickshell.clockPrecision` names the Quickshell
`SystemClock` precision member, emitted as a QML enum expression.
`desktopPolicy.quickshell.clockFormat` is emitted as the Qt date-time format.
The desktop policy uses `SystemClock.Seconds` with `yyyy-MM-dd HH:mm:ss`; the
laptop uses `SystemClock.Minutes` with `yyyy-MM-dd HH:mm`. The generated
`DesktopPolicy.qml` is consumed by the shared shell.

| Output | Composition |
|---|---|
| `nixosConfigurations.desktop` | `nixosSystem` with shared VM host, `account-black`, stock kernel, Hjem, and `policy-desktop`; hostname `nixos-desktop`. |
| `nixosConfigurations.laptop` | Same host baseline/account/kernel and Hjem with `policy-laptop`; hostname `nixos-laptop`. |
| `programmodConfigurations."black@desktop"` | Standalone programmod configuration with shared user preferences, base/development/desktop profiles and sources plus `policy-desktop` (`SystemClock.Seconds`, `yyyy-MM-dd HH:mm:ss`, `SUPER + SPACE`). |
| `programmodConfigurations."black@laptop"` | Same standalone profile/source modules plus `policy-laptop` (`SystemClock.Minutes`, `yyyy-MM-dd HH:mm`, `SUPER + V`). |
| `packages.x86_64-linux.programmod-configDir-black-*` | Buildable `.config` trees from `build.configDir`. |
| `packages.x86_64-linux.programmod-packages-black-*` | Buildable package environments from each standalone config's `packages`. |

The `nvf` program module calls nvf's independent configuration API; its
`settings.vim` data is passed to the upstream typed module options and
`nvf.sections` is rendered into `vim.luaConfigRC`. TOML-backed program
settings use `pkgs.formats.toml` and `builtins.readFile`, which requires
import-from-derivation (IFD) and evaluates a small TOML generator.

Both host outputs preserve the existing VM hardware and system packages.
The Hjem input follows `nixpkgs`; `flake.lock` pins the inputs. Home Manager
module integration/activation outputs are removed, while the Home Manager CLI
remains a nixpkgs package in the base profile. The CachyOS kernel module/input
remains available but is not selected by either host.

### Source boundaries

- `system/hosts/vm/hardware.nix`: persistent root/EFI filesystems, systemd-boot,
  virtio modules, QEMU guest service and existing VM variant sizing.
- `home/config/hypr/` and `home/config/quickshell/`: shared compositor and shell
  source; `home/config/hypr/host-vm.lua` retains VM monitor/gap settings.
- `home/users/black/config/quickshell/`: user-owned QML settings.
- `deployments/`: output composition only; it does not own duplicate host or
  user configuration sources.

Programmod files may contain generated text or file/directory sources under
`~/.config`. Hjem maps them to `xdg.config.files`, forwards program packages to
the user, and passes environment values to `environment.sessionVariables`.
The Fish program module renders the same `programmod-environment` section from
`config.environment` as Fish-native `set -gx` lines after `settings` for both
Hjem and standalone delivery. Standalone configs also expose a POSIX
`build.loadEnv` script for other shell bootstrap paths.

TOML settings are rendered with `pkgs.formats.toml` and `builtins.readFile`;
this uses IFD during evaluation. Nix commands that evaluate those settings
must permit import-from-derivation.

No switch or activation was performed. Building a NixOS output does not
activate its Hjem configuration, and building standalone programmod outputs
does not activate files or packages.

## 5. Further reference

- [Vimjoyer Nix index](https://www.vimjoyer.com/nix): compact examples for flakes, flake-parts, shells, and dendritic module layouts; examples here are adapted only as cross-reference, while repository paths and behavior above are independently verified.
