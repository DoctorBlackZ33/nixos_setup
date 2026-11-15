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
| `path:/home/black/experimental#nixosConfigurations.desktop` | URI plus `#` attribute selector. Quote selectors containing `@`, spaces, or shell metacharacters. |
| `path:./framework` | Relative path input. Its files must be git-tracked, and a changed input list needs `nix flake update framework`. |
| `github:owner/repo` / `github:owner/repo/ref` | GitHub shorthand; `ref` can be branch, tag, or revision. |
| `#attr` | Output selector, e.g. `'path:/home/black/experimental#hjemConfigurations."black@imac"'`. |

Outputs of this repository:

| Output | Contents |
|---|---|
| `nixosConfigurations.<name>` | one per deployment whose host is `managed = "nixos"` |
| `systemConfigs.<name>` | one per `managed = "system-manager"` host |
| `hjemConfigurations."<user>@<name>"` | one per user on a host that is not NixOS; the value `hjem standalone switch` reads |
| `checks.<platform>.*` | `nixos-<name>`, `system-<name>`, `home-<user>@<name>`, and `framework-*` |
| `packages.<system>.{hjem,system-manager,agenix}` | operator tools at the locked revisions (`agenix` only with secrets enabled) |
| `agenix-rekey` | read by the agenix CLI; only with secrets enabled |

The framework flake exposes `flakeModules.default`, `lib` and `modules`
(`homeMod`, `nixos`, `systemManager`). `nix flake check` prints
`unknown flake output` for `modules`, `systemConfigs` and `hjemConfigurations`;
that is expected.

### Evaluation, realization, activation

| Stage | What happens | Commands here |
|---|---|---|
| Evaluation | Parse and evaluate the flake and the selected output; type, option and assertion errors appear here. | `nix eval`, `nix flake check --no-build` |
| Realization | Build derivations into `/nix/store`; nothing is switched. | `nix build`, `nix flake check` |
| Activation | Change a running system or a home directory. | `nixos-rebuild switch`, `system-manager switch`, `hjem standalone switch` |

Evaluation never builds anything here: no module reads a generated file back.
`--option allow-import-from-derivation false` proves it and is part of the
check command.

### Commands

```sh
F='path:/home/black/experimental'

# everything, for every platform, evaluation only
nix flake check --no-build --all-systems --option allow-import-from-derivation false "$F"

# one deployment
nix build --no-link "$F#checks.x86_64-linux.nixos-desktop"

# what a host is, what is asked of it, what it supplies
nix eval --json "$F#nixosConfigurations.desktop.config.contract.facts"
nix eval --json "$F#nixosConfigurations.desktop.config.contract.provides.services"
nix eval --json "$F#nixosConfigurations.desktop.config.contract.wanted" \
  --apply 'w: builtins.mapAttrs (_: kind: builtins.mapAttrs (_: want: want.sources) kind) w'

# a generated user file
nix eval --raw "$F#nixosConfigurations.desktop.config.hjem.users.black.homeMod.files.\".config/hypr/hyprland.lua\".text"

# activation
sudo nixos-rebuild switch --flake "$F#desktop"
nix run "$F#system-manager" -- switch --flake "$F#<name>" --sudo
nix run "$F#hjem" -- standalone switch --flake "$F" --flake-attr 'hjemConfigurations."<user>@<name>"'
```

| Flag | Effect |
|---|---|
| `--no-build` | Evaluate check derivations without building them. |
| `--all-systems` | Also evaluate checks of platforms other than the current one. |
| `--no-update-lock-file` | Refuse lock-file changes; use it to prove the committed locks are complete. |
| `--no-link` | Build without creating a `result` symlink. |

## 3. Module-system notes

### Which module sees what

| Scope | Arguments | Files |
|---|---|---|
| flake-parts module | `config`, `lib`, `inputs`, `self`; `pkgs` only inside `perSystem` | `flake.nix`, `framework/flake-module.nix` |
| NixOS module | `config`, `lib`, `pkgs`, `framework`, plus `framework.moduleArgs` | hostConf, `framework/system/**`, `framework/adapters/nixos*.nix` |
| system-manager module | same arguments, far fewer options | hostConf of such hosts, `framework/system/common` |
| Hjem user module | `config`, `lib`, `pkgs`, `osConfig` | `framework/adapters/hjem.nix` only |
| homeMod module | `config`, `lib`, `pkgs`, `facts`, `inputs` (the framework's), `framework`, `secretsDirectory`, plus `framework.moduleArgs` | `framework/home/*.nix`, `users/<user>`, `hosts/<host>/users/<user>.nix` |

A homeMod module cannot read NixOS options: it is a different module class and
receives no `osConfig`.

### Traps found in this repository

| Trap | Consequence | What the code does instead |
|---|---|---|
| `lib.mkIf false { some.option = …; }` where `some.option` is not declared | "option does not exist", even though the condition is false | Modules are split by class: `system/common` loads under system-manager, `system/nixos` does not |
| One module sets `hjem.extraModules` and reads `config.hjem.users` | The user set is silently empty: Hjem builds the type of `users` from `extraModules` | `hjem-register.nix` registers, `nixos-users.nix` reads |
| `lib.optional cond x` or `map f (attrNames …)` in a definition set, with `cond` derived from the user layer | Forced while definitions are collected: recursion, or an empty result | `lib.mkIf`, or the value of an option |
| `mkIf false` on an attribute of a freeform set (flake outputs) | The attribute exists and throws when touched | `lib.optionalAttrs` |
| `builtins.readFile` of a `pkgs.formats` output | A build during evaluation; fails for a foreign platform | `source = format.generate …` |
| `types.lines` with several definitions of equal priority | Order follows module order, which is not stable | Named sections with an explicit `order` |
| An option default such as `{ }` on a submodule-typed option | The default bypasses the type, so nested defaults are missing | No default: the type supplies the empty value |

## 4. This repository: graph and data flow

### Inputs

The root `flake.nix` pins every dependency; the framework declares the same
inputs and follows them, so the root lock decides what is deployed.

| Input | Used for |
|---|---|
| `nixpkgs` | every host and user |
| `flake-parts` | both flakes |
| `hjem` | user layer on NixOS (module) and elsewhere (`hjem standalone`) |
| `system-manager` | system layer on non-NixOS hosts; its release branch must match the nixpkgs release |
| `nvf` | `framework/home/nvf.nix` |
| `agenix`, `agenix-rekey` | secrets provider, imported only when `framework.secrets` is set |
| `framework` | `path:./framework` |

`framework/flake.lock` is only used when the framework's checks run on their
own; it is kept at the same revisions. The root flake runs the same checks
against its own lock as `checks.<system>."framework-*"`.

### From inventory to outputs

1. `deployments.nix` names a deployment, its host directory and its users.
2. `framework/lib/facts.nix` turns `hosts/<host>/facts.nix` plus an optional
   `facter.json` into one typed value. Hand-written facts win; `null` means
   unknown.
3. `framework/lib/fleet.nix` validates names and files, then builds what
   `facts.managed` asks for:
   - `nixos`: `system/common` + `system/nixos` + hostConf, and, if the
     deployment has users, Hjem with one `homeMod` per user;
   - `system-manager`: `system/common` + hostConf; the users' requirements are
     passed in as data;
   - `manual`: nothing for the system.
   Users on the last two are evaluated on their own and exported as
   `hjemConfigurations`.
4. Every evaluation collects requests by source (`system`, `user <name>`),
   merges them into `contract.wanted`, lets provider modules react, and
   reconciles against `contract.provides` and the facts. Errors become one
   failing assertion (or a `throw` for standalone users), warnings become
   warnings.
5. Each deployable thing becomes a check for its own platform.

### Where things live

| Path | Holds |
|---|---|
| `framework/lib/capabilities.nix` | the table of capability kinds; types, merging and reconcile derive from it |
| `framework/lib/{contract,reconcile,facts,inventory,fleet,home,sections,modules}.nix` | types, pure logic, the builder |
| `framework/home/` | one module per program: mechanism only |
| `framework/system/common/` | modules that also load under system-manager |
| `framework/system/nixos/` | NixOS modules; `desktop.nix`, `audio.nix`, `pam.nix` are capability providers |
| `framework/system/optional/` | providers enabled by a flake setting (`agenix.nix`) |
| `framework/adapters/` | translation only: contract wiring, NixOS, Hjem, standalone, system-manager |
| `framework/checks/` | unit checks and the synthetic fleet |
| `users/black/` | `cli.nix`, `development.nix`, `desktop.nix`, `nvim.nix`, each gated on `facts.kind`, plus Hyprland and Quickshell sources |
| `hosts/common/` | hardware and values shared by the two reference hosts |
| `hosts/<host>/` | facts, optional report, hostConf, optional per-user override |

### Generated user files

Paths are relative to the home directory.

| Kind | Mechanism | Examples |
|---|---|---|
| Structured | `settings` typed by `pkgs.formats`, written with `format.generate` | git, gh, direnv, yazi, fuzzel, mako |
| Assembled text | named `sections` with `order` (500 before, 1000 default, 1500 after), replaceable or disabled by name | `config.fish`, `hyprland.lua`, `DesktopPolicy.qml` |
| Sources | paths handed through unchanged | Hyprland fragments, Quickshell trees |

`hyprland.lua` sections, in order: `settings` (`hl.config` from
`hyprland.settings`), `sources` (`dofile` per fragment), `policy` (the
floating-toggle chord, if set), `startup`.

## 5. Further reference

- [Vimjoyer Nix index](https://www.vimjoyer.com/nix): compact examples for flakes, flake-parts, shells, and dendritic module layouts; examples here are adapted only as cross-reference, while repository paths and behavior above are independently verified.
