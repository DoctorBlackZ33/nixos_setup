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
| `/absolute/file`, `./relative/file`, `../parent/file` | Path literal; relative paths resolve relative to the file containing the expression and are copied/content-addressed when used as a flake input. | `./home/modules/git.nix` |
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
| Evaluation vs build | Evaluation computes the expression/output graph and may fetch/evaluate source inputs; realization builds derivations; activation performs system/home side effects. `nix eval` does not build; `nix build` does not activate. |
| Purity | Flake evaluation is locked and normally pure: undeclared filesystem/network/environment dependencies are rejected or ignored. `--impure` permits ambient values such as `NIX_PATH` and environment variables. `builtins.pathExists` can inspect declared/local paths; a path source can be copied into the store, while `mkOutOfStoreSymlink` intentionally keeps a live filesystem path. |
| String vs path | A path literal carries source-location semantics and is eligible for store copying; a string containing `/etc/nixos/...` is only text. Convert deliberately with `toString`/`builtins.toPath` where supported. |
| Module file vs module value | `./x.nix` is a path value; `imports = [ ./x.nix ]` asks the module system to import it. A module value can instead be `{ config, lib, ... }: { ... }`. |

## 2. Flakes and command-line lookup

### Flake reference and output selection

| Form | Interpretation |
|---|---|
| `path:/etc/nixos` | Explicit local flake URI; avoids ambiguity with a bare path. |
| `path:/etc/nixos#nixosConfigurations.nixos-dev` | URI plus `#` attribute selector; selectors traverse attributes with dots. Quote selectors containing `@`, spaces, or shell metacharacters. |
| `github:owner/repo` / `github:owner/repo/ref` | GitHub shorthand; `ref` can be branch, tag, or revision. |
| `git+https://host/repo?ref=main&rev=...` | Explicit Git transport and query parameters; `rev` pins content, `ref` names the requested ref. |
| `./.` / `path:.` | Local flake path; lock metadata records a content hash/mtime and dirty-tree status as applicable. |
| `#attr` | Output selector shorthand when the flake URI is supplied separately (for example `nix build .#packages.x86_64-linux.default`). In shell, quote `path:/etc/nixos#homeConfigurations."black@vm".activationPackage`. |

Standard output conventions: `packages.<system>.<name>` (buildable packages), `apps.<system>.<name>` (runnable apps), `devShells.<system>.<name>`, `checks.<system>.<name>`, `formatter.<system>`, and `templates`. This repository additionally exposes `nixosConfigurations`, `homeConfigurations`, and flake-parts registries under `modules`; those are valid custom attrs but are not all classified by `nix flake show` as standard buildable outputs.

### Evaluation, realization, activation

| Stage | What happens | Commands here |
|---|---|---|
| Evaluation | Parse/evaluate `flake.nix`, locked inputs, modules, and selected output; errors are type/option/assert/import failures. | `nix flake show`, `nix flake metadata`, `nix eval`, `nix flake check --no-build` |
| Realization | Build selected derivation and dependencies into `/nix/store`; no system/home switch. | `nixos-rebuild build`; `nix build` |
| Activation | Run generated activation logic and change the running system or user home. | `sudo nixos-rebuild switch`; `home-manager switch` |

### Commands and flags used in this repository

| Command / flag | Effect |
|---|---|
| `nix flake show URI` | Summarizes recognized outputs; custom attrs may appear as `unknown`. |
| `nix flake metadata URI` | Shows locked URI, fingerprint, and input revisions without switching. |
| `nix flake check --no-build URI --print-build-logs` | Evaluates checks and module/output consistency; `--no-build` avoids realization. |
| `nix eval URI#attr --apply builtins.attrNames` | Evaluates an attr set and prints its keys; use `--json` for machine-readable output. |
| `nix build --no-link URI#attr` | Realizes a derivation without making `./result`; omit `--no-link` to create a result symlink. |
| `--no-update-lock-file` | Refuses lock-file updates. |
| `--no-write-lock-file` | Does not write a generated lock file; use with read-only inspection/builds. |
| `--flake URI` | `nixos-rebuild`/`home-manager` selector for a flake and output. |
| `--print-build-logs` | Streams build logs when builds are allowed. |
| `--no-build` | Evaluation/check mode; does not realize derivations. |
| `--no-link` | Build without creating a result symlink. |

Copy-paste read-only output queries:

```sh
nix flake show --no-update-lock-file --no-write-lock-file path:/etc/nixos
nix flake metadata --no-update-lock-file --no-write-lock-file path:/etc/nixos
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/etc/nixos#nixosConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/etc/nixos#homeConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/etc/nixos#modules.homeManager --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/etc/nixos#modules.nixos --apply builtins.attrNames
```

Build without activation or lock writes:

```sh
nixos-rebuild build --flake 'path:/etc/nixos#nixos-dev' \
  --no-update-lock-file --no-write-lock-file
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/etc/nixos#homeConfigurations."black@vm".activationPackage'
```

Enter the repository's per-system development shell (the `devShells.x86_64-linux.default` output):

```sh
nix develop --no-update-lock-file --no-write-lock-file path:/etc/nixos
```

Activate the two independent configurations sequentially:

```sh
sudo nixos-rebuild switch --flake 'path:/etc/nixos#nixos-dev' \
  --no-update-lock-file --no-write-lock-file
home-manager switch --flake 'path:/etc/nixos#black@vm' \
  --no-write-lock-file
```

`nixos-dev` is host-only NixOS; Home Manager is standalone and evaluated/activated independently. A combined shell sequence is sequential and non-atomic:

```sh
sudo nixos-rebuild switch --flake 'path:/etc/nixos#nixos-dev' \
  --no-update-lock-file --no-write-lock-file &&
home-manager switch --flake 'path:/etc/nixos#black@vm' \
  --no-write-lock-file
```

With `&&`, a failed NixOS switch prevents the Home Manager command; if NixOS succeeds and Home Manager fails, the NixOS generation remains active while the home remains at its prior generation. Run `home-manager` as `black`, without `sudo`.

## 3. flake-parts semantics

### Module scopes and arguments

`flake-parts.lib.mkFlake { inherit inputs; } module` runs a Nix module system whose final `config.flake` becomes flake outputs. `config` and `options` are the flake-parts module-system state, not NixOS or Home Manager state.

| Scope | Common module arguments | What `config` means | What this repo uses |
|---|---|---|---|
| Top-level flake-parts module | `config`, `options`, `lib`, `inputs`, `self`, `getSystem`, `moduleWithSystem`, `withSystem`; `system`/`pkgs` are not generally available here. | Global flake-parts options, including `config.flake`, `config.perSystem`, `config.systems`, and registries. | All `flake-module.nix` files define registries or outputs here. |
| `perSystem = { system, pkgs, ... }: { ... }` | `system`, `pkgs`, `self'`, `inputs'`, plus module `config`/`lib`; only explicitly named function parameters are passed. | The current system's per-system option namespace. | `system/modules/flake-module.nix` defines `formatter` and `devShells.default`. |
| `withSystem "x86_64-linux" ({ pkgs, system, ... }: expr)` | Per-system context selected explicitly; `pkgs` is the pinned nixpkgs package set for that system. | The selected per-system context while constructing `expr`. | Deployments construct all three standalone Home Manager configurations. |
| NixOS module | `config`, `options`, `lib`, `pkgs`, `modulesPath`, and declared special args. | NixOS option tree (`services`, `boot`, `users`, etc.). | `host-vm`, `system-*`, `kernel-*`, and `user-black-account`. |
| Home Manager module | `config`, `options`, `lib`, `pkgs`, and Home Manager special args. | Home Manager option tree (`home`, `programs`, `myHome`, etc.). | `user-black`, profiles, and `home/modules/*`. |

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
| `flake.foo = value;` | Defines a top-level flake output attr. Nested attrs such as `flake.nixosConfigurations` and `flake.homeConfigurations` become outputs verbatim. |
| `perSystem = { ... }: { formatter = ...; devShells.default = ...; };` | Defines system-specific options; flake-parts transposes supported per-system outputs to `formatter.<system>` and `devShells.<system>`. |
| Transposition boundary | Only options declared by flake-parts as per-system options are transposed. A top-level `flake.homeConfigurations` set is not automatically converted to a per-system attr. |
| `flake.modules.<namespace>.<name> = module;` | With `inputs.flake-parts.flakeModules.modules` imported, registers reusable modules under a named namespace. Registries are ordinary flake attrs and are consumed by later modules through `config.flake.modules`. |

A list option normally concatenates definitions; an attr-set option recursively merges keys; scalar options conflict unless priorities select one. Module merging is distinct from Nix `//`: `//` is a shallow expression-level update, while the module system applies option types, priorities, conditionals, and declarations.

Common flake-parts failure modes: using `pkgs`/`system` at top level instead of `withSystem`/`perSystem`; omitting a module from root `imports`; importing a NixOS module into a Home Manager module (or vice versa); defining `config` as if it were a plain set rather than option definitions; relying on `//` for a deep module merge; using an unlisted system; creating a cycle where a registry module imports the output that consumes it; and using an unquoted `#`/`@` selector in the shell. A missing option declaration, wrong option type, duplicate scalar definition, or missing attr selection fails during evaluation rather than at activation.

## 4. This repository: graph and data flow

### Root and input graph

`/etc/nixos/flake.nix` declares these locked inputs:

| Input | URL / relation | Consumers |
|---|---|---|
| `nixpkgs` | `https://releases.nixos.org/nixos/26.05/nixos-26.05.6503.21ea275a7c46/nixexprs.tar.xz` | `nixosSystem`, `pkgs`, system and Home Manager packages. |
| `home-manager` | `https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz`; `inputs.nixpkgs.follows = "nixpkgs"` | Flake module and `homeManagerConfiguration`. |
| `nvf` | `github:NotAShelf/nvf`; follows root `nixpkgs` | `module-nvf` Home Manager module and editor configuration. |
| `nix-cachyos-kernel` | Pinned archive at `dbae8dc454556968710401643aa2c6867d166440.tar.gz` | `kernel-cachy` overlay and kernel package set. |
| `flake-parts` | `github:hercules-ci/flake-parts` | `mkFlake` and `flakeModules.modules`. |

Root `outputs = inputs @ { flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } { ... }` sets `systems = [ "x86_64-linux" ]` and imports, in order, `inputs.flake-parts.flakeModules.modules`, `inputs.home-manager.flakeModules.home-manager`, `./system/modules/flake-module.nix`, `./system/hosts/vm/flake-module.nix`, `./home/modules/flake-module.nix`, `./home/profiles/flake-module.nix`, `./home/users/black/flake-module.nix`, and `./deployments/flake-module.nix`.

### Registries and consumers

| Registry entry | Defined by | Imports / defines | Consumed by |
|---|---|---|---|
| `config.flake.modules.nixos.system-base`, `system-desktop`, `system-development`, `platform-x86_64-linux`, `kernel-stock`, `kernel-cachy` | `system/modules/flake-module.nix` | Reusable NixOS policy; `kernel-cachy` applies `inputs.nix-cachyos-kernel.overlays.pinned`. | `system/hosts/vm/flake-module.nix`, `deployments/vm/default.nix`. |
| `config.flake.modules.nixos.host-vm` | `system/hosts/vm/flake-module.nix` | Imports platform, base, desktop, development, and `./hardware.nix`; sets `nixos-dev`, locale, services, VM software rendering, and state version. | Both NixOS deployments. |
| `config.flake.modules.nixos.user-black-account` | `home/users/black/flake-module.nix` | Creates immutable normal user `black` with fish, groups, and bootstrap hashed password. | Both NixOS deployments. |
| `config.flake.modules.homeManager.module-*` | `home/modules/flake-module.nix` | Registers each Home Manager module, including `inputs.nvf.homeManagerModules.default`; `module-set` imports all module entries. | `user-black`. |
| `config.flake.modules.homeManager.profile-base`, `profile-desktop`, `profile-development` | `home/profiles/flake-module.nix` | Profiles define `myHome.*.enable` values. | `user-black`. |
| `config.flake.modules.homeManager.user-black` | `home/users/black/flake-module.nix` | Imports `module-set` and all profiles; sets identity (`black`, `/home/black`, `26.05`), editor, and Git identity. | All standalone Home Manager deployments. |
| Deployment definitions | `deployments/standalone/black.nix`, `deployments/vm/default.nix`, `deployments/vm/black/flake-module.nix` | Consume registries and construct output attrs. | Final flake outputs. |

`config.flake.modules` is the reusable registry namespace supplied by flake-parts' `modules` flake module. This is distinct from the conventional `nixosModules`/`homeModules` outputs; in the current evaluation, `modules` has keys `homeManager` and `nixos`, while `nixosModules` and `homeModules` are empty sets.

Dependency direction is one-way: locked `inputs` feed the root `mkFlake` module; root `imports` define registries and per-system values; registry/profile modules define reusable pieces; deployments consume those pieces to instantiate `nixosConfigurations` or standalone `homeConfigurations`; CLI commands select and realize/activate the final outputs. A registry must not depend back on a deployment output, and a NixOS/Home Manager module must not be mistaken for a flake-parts module.

### Output graph

```text
flake.nix
  ├─ flake-parts module + Home Manager flake module
  ├─ system/modules/flake-module.nix
  │    ├─ modules.nixos.{system-base,system-desktop,system-development,
  │    │  platform-x86_64-linux,kernel-stock,kernel-cachy}
  │    └─ perSystem.x86_64-linux.{formatter,devShells.default}
  ├─ system/hosts/vm/flake-module.nix
  │    └─ modules.nixos.host-vm -> hardware.nix + system modules
  ├─ home/modules/flake-module.nix -> modules.homeManager.module-set + module-*
  ├─ home/profiles/flake-module.nix -> profile-{base,desktop,development}
  ├─ home/users/black/flake-module.nix
  │    ├─ modules.homeManager.user-black
  │    └─ modules.nixos.user-black-account
  └─ deployments/flake-module.nix
       ├─ deployments/vm/default.nix
       │    ├─ nixosConfigurations.nixos-dev      -> kernel-stock
       │    └─ nixosConfigurations.nixos-dev-cachy -> kernel-cachy
       ├─ deployments/standalone/black.nix
       │    └─ homeConfigurations.black
       └─ deployments/vm/black/flake-module.nix
            ├─ homeConfigurations."black@vm"
            └─ homeConfigurations."black@vm-live"
```

| Final output | Module composition and source semantics |
|---|---|
| `nixosConfigurations.nixos-dev` | `inputs.nixpkgs.lib.nixosSystem` with `modules.host-vm`, `modules.user-black-account`, an inline greetd session (`tuigreet --time --cmd start-hyprland`), and `modules.kernel-stock`. |
| `nixosConfigurations.nixos-dev-cachy` | Same host/account/session, but `modules.kernel-cachy`; this adds the pinned CachyOS overlay and `cachyosKernels."linuxPackages-cachyos-latest-lto-x86_64-v4"`. |
| `homeConfigurations.black` | `withSystem "x86_64-linux"`; `homeManagerConfiguration { pkgs; modules = [ modules.user-black production ]; }`. Production Lua uses `home/config/hypr/{base.lua,features/keybinds.lua,features/session.lua,themes/default.lua}` plus an optional `home/users/black/config/hypr/override.lua`; Quickshell uses `deployments/standalone/black/config/quickshell/shell.qml`, `.../deployment`, shared `home/config/quickshell`, and user `home/users/black/config/quickshell`. |
| `homeConfigurations."black@vm"` | Same standalone Home Manager constructor and user module; production Lua adds `deployments/vm/black/config/hypr/host.lua`, uses `vm-black`, and Quickshell sources `deployments/vm/black/config/quickshell/shell.qml` and `components` plus shared/user trees. |
| `homeConfigurations."black@vm-live"` | Same user module with `live`; all Lua paths are absolute `/etc/nixos/...`, and Quickshell entries use `config.lib.file.mkOutOfStoreSymlink` for `/etc/nixos/deployments/vm/black/config/quickshell/shell.qml`, `components`, shared, and user trees. It intentionally follows edits outside the Nix store. |

The module implementation `home/modules/hyprland.nix` maps each fragment to `dofile(<JSON path>)`, optionally inserts startup callbacks before the final fragment, and writes `.config/hypr/hyprland.lua`. `home/modules/quickshell.nix` maps named entries to `.config/quickshell/${activeConfig}/${name}`; `recursive = false` links/copies the root entry as configured. These are Home Manager option merges, not flake-parts output merges.

### Verified current output names

Read-only evaluation of `path:/etc/nixos` currently returns:

```text
nixosConfigurations = [ "nixos-dev" "nixos-dev-cachy" ]
homeConfigurations  = [ "black" "black@vm" "black@vm-live" ]
modules             = [ "homeManager" "nixos" ]
modules.nixos       = [ "host-vm" "kernel-cachy" "kernel-stock"
                        "platform-x86_64-linux" "system-base" "system-desktop"
                        "system-development" "user-black-account" ]
modules.homeManager = [ "module-custom-commands" "module-desktop-tools"
  "module-direnv" "module-fish" "module-fuzzel" "module-gh" "module-git"
  "module-home-manager" "module-hyprland" "module-lazygit" "module-mako"
  "module-nvf" "module-nvf-config" "module-quickshell" "module-set"
  "module-yazi" "module-zoxide" "profile-base" "profile-desktop"
  "profile-development" "user-black" ]
```

`nix flake show --no-update-lock-file --no-write-lock-file path:/etc/nixos` recognizes `devShells.x86_64-linux.default`, `formatter.x86_64-linux`, and the two NixOS configurations; it labels `homeConfigurations`, `homeModules`, and `modules` as `unknown` because they are custom/nonstandard attr types. Use the `nix eval --apply builtins.attrNames` queries above for authoritative names.

### Source paths and scope boundaries

- `/etc/nixos/system/modules/` contains reusable NixOS policy and the per-system formatter/dev shell.
- `/etc/nixos/system/hosts/vm/` contains host registry and hardware facts (`hardware.nix`).
- `/etc/nixos/home/modules/` contains reusable Home Manager modules; `/etc/nixos/home/profiles/` contains profile definitions.
- `/etc/nixos/home/users/black/` contains identity and user-owned sources.
- `/etc/nixos/deployments/` is the composition boundary: it binds host/account/source layout to outputs.
- `/etc/nixos/home/config/` is shared QML/Hyprland/Mako/Fuzzel source; `/etc/nixos/deployments/vm/black/config/` is VM-specific source.

NixOS is host-only in this graph: `nixosConfigurations.*` does not embed a Home Manager activation. Home Manager uses `inputs.home-manager.lib.homeManagerConfiguration` as standalone outputs and therefore has its own generation and activation command. There is no atomic combined activation; running both switches is two sequential side effects.

## 5. Further reference

- [Vimjoyer Nix index](https://www.vimjoyer.com/nix): compact examples for flakes, flake-parts, shells, and dendritic module layouts; examples here are adapted only as cross-reference, while repository paths and behavior above are independently verified.
