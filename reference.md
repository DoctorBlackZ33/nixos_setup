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
| `/absolute/file`, `./relative/file`, `../parent/file` | Path literal; relative paths resolve relative to the file containing the expression and are copied/content-addressed when used as a flake input. | `./framework/home/git.nix` |
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

Precedence 1 binds tightest. The examples were evaluated with Nix 2.34, with
`s = { y = 1; h = x: x * 2; }`, `f = x: x + 1` and `g = x: y: x - y`.

| Precedence | Operators / form | Associativity | Meaning; how an example groups |
|---:|---|---|---|
| 1 | `a.b`, `a."key"`, `a.b or d` | none | Attribute selection; `or d` belongs to the selection and is used only when the path is missing. `f s.y` is `f (s.y)`; `f s.x or 0` is `f (s.x or 0)`; `s.h 3` is `(s.h) 3`. |
| 2 | `f x` | left | Function application. `g 5 3` is `(g 5) 3`. |
| 3 | `-x` | none | Arithmetic negation. `-f 3` is `-(f 3)`. |
| 4 | `a ? b` | none | Has attribute. `!s ? y` is `!(s ? y)`; `s ? y == true` is `(s ? y) == true`. |
| 5 | `++` | right | List concatenation; it does not merge attribute sets. `[ 1 ] ++ [ 2 ] * 3` fails in the multiplication, whose first argument is `[ 1 2 ]`. |
| 6 | `*`, `/` | left | Multiplication, division. `1 + 2 * 3` is `7`. |
| 7 | `+`, `-` | left | Addition (also string and path concatenation), subtraction. `10 - 2 - 3` is `5`. |
| 8 | `!x` | none | Boolean negation. `!true == false` is `(!true) == false`, so `true`. |
| 9 | `//` | right | Shallow attribute-set update: keys on the right win; nested sets are replaced, not merged (`lib.recursiveUpdate` merges deeply). `a // b == c` is `(a // b) == c`. |
| 10 | `<`, `<=`, `>`, `>=` | none | Ordering comparison. `1 < 2 == true` is `(1 < 2) == true`; `1 < 2 < 3` is a syntax error. |
| 11 | `==`, `!=` | none | Equality, inequality. `1 == 1 && false` is `(1 == 1) && false`; `1 == 1 == true` is a syntax error. |
| 12 | `&&` | left | Logical AND; the right side is evaluated only when needed. `true \|\| false && false` is `true \|\| (false && false)`. |
| 13 | `\|\|` | left | Logical OR; the right side is evaluated only when needed. |
| 14 | `->` | right | Logical implication, `a -> b` is `!a \|\| b`. `false -> true && false` is `false -> (true && false)`, so `true`; `false -> false -> false` is `false -> (false -> false)`, so `true`. |

Use parentheses around mixed arithmetic, list concatenation, updates, and conditionals; e.g. `((base // override) // extra)` and `if ok then (a ++ b) else []`. `=` is a set/`let` binding delimiter, `:` introduces a function, and `;` terminates a binding or expression statement; none is an assignment operator.

### Evaluation, imports, derivations, purity

| Topic | Lookup |
|---|---|
| Laziness | Nix uses call-by-need: a binding/list element/attribute is evaluated only when demanded, then shared. A set can be constructed without evaluating every value; `builtins.deepSeq` forces a whole value before returning another. |
| `import path` | Reads and evaluates a Nix file; the result may be any Nix value, commonly a function (`import ./module.nix args`) or set. Relative paths resolve relative to the importing file. `import <nixpkgs>` depends on `NIX_PATH`; flake code should use the locked `inputs.nixpkgs` instead. |
| Derivation | A derivation is a lazy recipe/value (usually from `pkgs.stdenv.mkDerivation`); evaluation creates a `.drv` plan, while realization (`nix build`, a system switch, or a dependency demand) executes it and produces store paths. A derivation is an attr set with `type = "derivation"`. |
| Evaluation vs build | Evaluation computes the expression/output graph and may fetch/evaluate source inputs; realization builds derivations; activation performs system/home side effects. `nix eval` usually does not realize derivations, but import-from-derivation can build a generator during evaluation (this repository avoids it, see below); `nix build` does not activate. |
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
| `github:owner/repo` / `github:owner/repo/ref` | GitHub shorthand; `ref` can be branch, tag, or revision. A branch is locked to its current revision and moves only with `nix flake update`. |
| `#attr` | Output selector, e.g. `'path:/home/black/experimental#hjemConfigurations."black@imac"'`. |

Outputs of this repository:

| Output | Contents |
|---|---|
| `nixosConfigurations.<name>` | one per deployment whose host is `managed = "nixos"` |
| `systemConfigs.<name>` | one per `managed = "system-manager"` host |
| `hjemConfigurations."<user>@<name>"` | one per user on a host that is not NixOS; the value `hjem standalone switch` reads |
| `checks.<platform>.*` | `nixos-<name>`, `system-<name>`, `home-<user>@<name>`, `config`, and `framework-*` (see Checks in section 4) |
| `packages.<system>.{hjem,system-manager,agenix}` | operator tools at the locked revisions (`agenix` only with secrets enabled) |
| `packages.<system>.sync-framework-lock` | re-locks `framework/flake.lock` from `flake.lock` (`nix flake lock --reference-lock-file ../flake.lock --output-lock-file flake.lock` inside `framework/`), then compares the two locks path by path (`framework/lib/lock-drift.nix`) and exits non-zero, listing every input path that disagrees; run inside the checkout after `nix flake update` |
| `agenix-rekey` | read by the agenix CLI; only with secrets enabled |

The framework flake exposes `flakeModules.default`, `lib` and `modules`
(`homeMod`, `nixos`, `systemManager`); `lib.mkCheck` is the check helper the
root `checks.nix` uses. `nix flake check` prints `unknown flake output` for
`modules`, `systemConfigs` and `hjemConfigurations`; that is expected.

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
nix flake check --no-build --all-systems --no-update-lock-file --option allow-import-from-derivation false "$F"

# one deployment
nix build --no-link "$F#checks.x86_64-linux.nixos-desktop"

# the framework's checks against framework/flake.lock
nix flake check --no-build --all-systems --no-update-lock-file --option allow-import-from-derivation false "$F/framework"

# update the inputs, then make the framework's lock agree (inside the checkout)
nix flake update                      # or one input: nix flake update nixpkgs
nix run .#sync-framework-lock

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
| `--reference-lock-file <file>` | Read `<file>` instead of the flake's own `flake.lock`; it only selects the lock to read. `sync-framework-lock` passes `../flake.lock` inside `framework/`, which forwards the root's complete input graph. |
| `--output-lock-file <file>` | Write the lock to `<file>`. `sync-framework-lock` passes `flake.lock`: with `--reference-lock-file` alone, Nix exits without writing when the graph already matches, leaving `framework/flake.lock` missing or stale. |

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

`pkgs` is the same package set on every path: the framework's one `nixpkgs`
input with `framework.overlays` and `framework.nixpkgsConfig` applied. Hjem
users inside NixOS get the system's `pkgs`; standalone users get one set per
platform, built the same way.

### Traps found in this repository

| Trap | Consequence | What the code does instead |
|---|---|---|
| `lib.mkIf false { some.option = …; }` where `some.option` is not declared | "option does not exist", even though the condition is false | Modules are split by class: `system/common` loads under system-manager, `system/nixos` does not |
| One module sets `hjem.extraModules` and reads `config.hjem.users` | The user set is silently empty: Hjem builds the type of `users` from `extraModules` | `hjem-register.nix` registers, `nixos-users.nix` reads |
| `lib.optional cond x` or `map f (attrNames …)` in a definition set, with `cond` derived from the user layer | Forced while definitions are collected: recursion, or an empty result | `lib.mkIf`, or the value of an option |
| `mkIf false` on an attribute of a freeform set (flake outputs) | The attribute exists and throws when touched | `lib.optionalAttrs` |
| `builtins.readFile` of a `pkgs.formats` output | A build during evaluation; fails for a foreign platform | `source = format.generate …` |
| `types.lines` with several definitions of equal priority | Order follows module order, which is not stable | Named sections with an explicit `order` |
| system-manager's `nixpkgs.overlays` option | It is typed `listOf anything`, and the wrapping it applies breaks an overlay that reads `prev` | The fleet builder passes the overlays as the `overlays` argument of `makeSystemConfig` |
| `nix flake update` in the root of an input the framework shares | `framework/flake.lock` keeps the old pins on the shared input paths, so the framework's checks run alone test other inputs than the deployed ones | `nix run .#sync-framework-lock` after every update; while shared input paths stay out of sync, the `config` check fails. A root-only input such as `nixpkgs-unstable` touches no shared path |
| `nixpkgs.legacyPackages.<system>` for users outside NixOS | Overlays and nixpkgs `config` reach NixOS systems but not standalone users | `fleet.nix` builds one package set per platform with `framework.overlays` and `framework.nixpkgsConfig` |
| A nixpkgs selector separate from the framework's own `nixpkgs` input | system-manager's `makeSystemConfig` captures its own nixpkgs input and has no nixpkgs argument, so a selector could not reach system-manager systems | No selector: every path is built from the framework's `nixpkgs` input, which the root `flake.nix` makes follow its `nixpkgs` (`framework.inputs.nixpkgs.follows = "nixpkgs"`) |
| An input that stops following the root's `nixpkgs` (for example `system-manager.inputs.nixpkgs` pointed elsewhere) | That input is built from another nixpkgs while everything else looks unchanged: "one nixpkgs" holds only while every `nixpkgs` edge follows the root's | The `config` condition "every input takes nixpkgs from the root" resolves every `nixpkgs` edge in `flake.lock` and fails with `different at: <input paths>`, for example `system-manager/nixpkgs` |
| `framework.deployments = { }` | Check platforms come from `systems`, which defaults to the fleet's platforms, so an empty inventory would run no check at all, `checks.config` included, and still pass | The flake module rejects it (`framework.deployments is empty. Add at least one host to deployments.nix`) |
| `systems` forced to a list without a deployment's platform (`lib.mkForce [ ]`, or another architecture only) | That host's checks never run, and `nix flake check` still reports success | The flake module rejects it (`systems must include every deployment platform (missing: …)`); additional platforms are allowed |
| Comparing the two lock files as a set of pins | A framework input could borrow a pin from an unrelated root input, for example a stable input pinned to the root's unstable revision, and still look synced | `framework/lib/lock-drift.nix` compares pins along the same dependency path; the `config` check and `sync-framework-lock` both use it |
| `nix flake lock --reference-lock-file` without `--output-lock-file` | When the graph already matches, Nix exits without writing, leaving `framework/flake.lock` missing or stale | `sync-framework-lock` names `--output-lock-file flake.lock`, then checks the result path by path |

## 4. This repository: graph and data flow

### Inputs

The root `flake.nix` pins every dependency; the framework declares the same
inputs and follows the root's, so the root lock decides what is deployed.
`nixpkgs-unstable` exists in the root only.

| Input | Reference | Used for |
|---|---|---|
| `nixpkgs` | `github:NixOS/nixpkgs/nixos-26.05` | every host and user; a branch, so `nix flake update nixpkgs` moves all of them |
| `nixpkgs-unstable` | `github:NixOS/nixpkgs/nixos-unstable` | single packages as `pkgs.unstable.<name>`, through `overlays/unstable.nix`; never a whole host |
| `flake-parts` | `github:hercules-ci/flake-parts` | both flakes |
| `hjem` | `github:feel-co/hjem` | user layer on NixOS (module) and elsewhere (`hjem standalone`) |
| `system-manager` | `github:numtide/system-manager/release-26.05` | system layer on non-NixOS hosts; its release branch must match the nixpkgs release |
| `nvf` | `github:NotAShelf/nvf` | `framework/home/nvf.nix` |
| `agenix`, `agenix-rekey` | `github:ryantm/agenix`, `github:oddlama/agenix-rekey` | secrets provider, imported only when `framework.secrets` is set |
| `framework` | `path:./framework` | the framework flake; each of its inputs follows the root's |

`framework/flake.lock` is only used when the framework's checks run on their
own, and it must agree with `flake.lock` at every input path the two share.
`framework/lib/lock-drift.nix` compares them path by path: it resolves each
node's input references and `follows` from both lock roots, compares the pins
along the same dependency path, treats `path` nodes as equal in type only
(their input edges are still compared), and tolerates cycles. Renamed nodes do
not count as drift; a pin reached through a different path does.
`nix run .#sync-framework-lock` runs
`nix flake lock --reference-lock-file ../flake.lock --output-lock-file flake.lock`
inside `framework/` and then the same comparison, exiting non-zero with the
input paths that disagree. The module exports the comparison (`drifted`) and
its resolver (`resolvePath`); the root's `config` check uses both and the tool
uses `drifted`, so the tool and the check cannot disagree. The root flake runs
the framework checks against its own lock as `checks.<system>."framework-*"`.

### Options of the framework flake module

Set under `framework` in the config flake's `flake.nix`; this repository sets
`root`, `deployments` and `overlays`.

| Option | Type | Default | Meaning |
|---|---|---|---|
| `root` | path | none (required) | directory containing `hosts/` and `users/` |
| `deployments` | the inventory schema (`framework/lib/inventory.nix`) | `{ }` | which users run on which host; here `import ./deployments.nix`. An empty inventory is rejected (see Traps in section 3) |
| `overlays` | list of overlays | `[ ]` | nixpkgs overlays for NixOS systems, system-manager systems (as `makeSystemConfig`'s `overlays` argument) and standalone users; here `overlays/unstable.nix` |
| `nixpkgsConfig` | attribute set | `{ }` | nixpkgs `config` (for example `allowUnfree = true`), applied on the same three paths |
| `moduleArgs` | attribute set | `{ }` | extra arguments for hostConf, userConf and every other module; `inputs`, `pkgs`, `facts`, `framework`, `secretsDirectory` and `osConfig` are rejected |
| `frameworkChecks` | bool | `true` | also run the framework's checks against this flake's lock as `checks.<system>."framework-*"` |
| `secrets` | null or `{ directory; masterIdentities; extraEncryptionPubkeys; }` | `null` | enables the agenix provider on every NixOS host; leave null until a master identity exists |

There is no option to select nixpkgs. Every delivery path is built from the
framework's own `nixpkgs` input, which the config flake makes follow its
`nixpkgs`, so the root lock decides. The `config` check fails when any input's
`nixpkgs` stops following the root's (see Traps in section 3). The guarantee
is one identical input, not identical content: `.path` and `outPath` are
metadata and do not prove that two package sets come from the same source, and
nothing hashes content at evaluation time (spec R9). The flake's `systems` (a
flake-parts option) defaults to the fleet's platforms; a list that omits one of
them is rejected (see Traps in section 3).

### Accounts

`users/<user>/account.nix` is plain data, typed by `framework/lib/accounts.nix`
for every deployment that lists the user. Accounts are created only on NixOS
hosts: there the fleet builder turns the file into `sysMod.accounts.<user>`
definitions. On system-manager and manual hosts the file is type-checked and a
mistake in it is refused, but no login is created and the distribution's
logins are left untouched. The host's own block, `sysMod.accounts.<user>` in
`hosts/<host>/default.nix`, has the same fields plus `groups`.

| Field | Type, default | Meaning | Where |
|---|---|---|---|
| `description` | string, `""` | full name or purpose | account file; a host may override |
| `uid` | positive integer or null, `null` | fixed user id; the shared default, so files keep their owner across hosts unless a host overrides it | account file; a host may override (another uid evaluates) |
| `shell` | `"bash"`, `"fish"` or `"zsh"`; `"bash"` | login shell; `bash` installs `bashInteractive`, whose package name `bash-interactive` counts as `bash` when identities are compared (`framework.lib.accounts.shellIdentity`); `fish` and `zsh` also enable `programs.<shell>` | account file; a host may override |
| `authorizedKeys` | list of strings, `[ ]` | SSH public keys allowed to log in | account file; a host adds its own |
| `hashedPassword` | string or null, `null` | password hash; readable in the store, so throwaway hosts only | account file or host |
| `hashedPasswordFile` | string or null, `null` | runtime path of a file holding the hash, for example a secret | account file or host |
| `groups` | list of strings, `[ ]` | supplementary groups on this host | host only |

Single values from the account file are defaults that the host's own value
replaces; lists add up. `groups`, `services` or any other unknown field in an
account file is rejected, and the error names the file and the field. The
typed account data accepts both `hashedPassword` and `hashedPasswordFile`;
only the NixOS accounts module (`framework/system/nixos/accounts.nix`) asserts
that the account a host ends up with does not set both. A host may declare
accounts for names without a `users/` directory. Once a host declares any
account, `users.mutableUsers` defaults to `false`.

### From inventory to outputs

1. `deployments.nix` names a deployment, its host directory and its users.
2. `framework/lib/facts.nix` turns `hosts/<host>/facts.nix` plus an optional
   `facter.json` into one typed value. Hand-written facts win; `null` means
   unknown.
3. `framework/lib/fleet.nix` validates names and files and types the account
   file of every listed user, then builds what `facts.managed` asks for:
   - `nixos`: `system/common` + `system/nixos` + hostConf + the package
     policy, the listed users' accounts as `sysMod.accounts.<user>`
     definitions, and, if the deployment has users, Hjem with one `homeMod`
     per user;
   - `system-manager`: `system/common` + hostConf, with the package policy
     (overlays as `makeSystemConfig`'s `overlays` argument); the users'
     requirements are passed in as data;
   - `manual`: nothing for the system.
   Users on the last two are evaluated on their own, with one package set per
   platform built with the same policy, and exported as `hjemConfigurations`.
4. Every evaluation collects requests by source (`system`, `user <name>`),
   merges them into `contract.wanted`, lets provider modules react, and
   reconciles against `contract.provides` and the facts. Errors become one
   failing assertion (or a `throw` for standalone users), warnings become
   warnings.
5. Each deployable thing becomes a check for its own platform.

### Checks

| Check | Defined in | What it covers |
|---|---|---|
| `nixos-<name>` | `framework/lib/fleet.nix` | the system toplevel of a NixOS deployment |
| `system-<name>` | `framework/lib/fleet.nix` | a system-manager config |
| `home-<user>@<name>` | `framework/lib/fleet.nix` | one standalone user's files and packages |
| `config` | `checks.nix` | the real configuration: `framework/flake.lock` agrees with `flake.lock` at every shared input path (`framework/lib/lock-drift.nix`); every input takes nixpkgs from the root: every node reachable from `flake.lock` that has an input named `nixpkgs` resolves it, through `follows` and node references, to the node the root's own `nixpkgs` resolves to (`resolvePath`), and a failure reads `different at: <input paths>`; `black` is deployed to both reference hosts with the same uid, description and shell on each, taken from `users/black/account.nix` (credentials and keys are not compared; shells compare by identity), and the host decides the groups; `pkgs.unstable` is a newer nixpkgs on every host and reaches the users inside NixOS; the server stays headless; the graphical layer reaches the workstation only; no contract assertion fails |
| `framework-<check>` | `framework/checks/default.nix` | the framework's checks against the root lock: `flake-inventory`, `lock-graph`, `reconcile-*`, `contract-types`, `facts`, `sections`, `home-*`, `fleet-nixos`, `fleet-servers`, `fleet-refusal`, `fleet-secrets`, `fleet-secret-decrypts`, `fleet-foreign`, `fleet-inventory`, `fleet-accounts`, `fleet-packages`, `fleet-host-<name>` |
| `framework-flake-inventory` | `framework/checks/default.nix` | the flake module's refusals: an empty inventory, even without check platforms, and a `systems` list that drops a deployment's platform, whether forced empty or holding only another architecture. Additional platforms are allowed, a nonempty inventory exports its hosts, and a manual host without users keeps its platform |
| `framework-lock-graph` | `framework/checks/default.nix` | `lock-drift.nix` on fixture locks: the same graph agrees; renamed nodes, follows and cycles preserve it; a stable pin borrowed from the root's unstable input, transitive pin drift, a follows path that borrows another root pin, a missing or extra dependency edge, and a framework input absent from the root are rejected |
| `framework-fleet-refusal` | `framework/checks/default.nix` | what the synthetic fleet must refuse: an ungated desktop user on a server of every kind, users of one host who disagree, a deployed user without an account, a host that contradicts or rewrites its facts, secrets on a manual host. Disabling a user's Hjem configuration removes their requests but does not waive a deployment's consequence: that user still needs an account |

The deployment checks are the deployed derivations themselves: evaluating them
runs the systems' assertions, building them builds the systems. `config` and
the framework's checks are built with `mkCheck` (`framework/lib/check.nix`):
named conditions decided during evaluation, so `--no-build` runs them, and a
failure lists the conditions that broke. The exception is
`fleet-secret-decrypts`, which needs a build: the rekeyed fixture secret must
decrypt with the fixture host key.

### Where things live

| Path | Holds |
|---|---|
| `framework/lib/capabilities.nix` | the table of capability kinds; types, merging and reconcile derive from it |
| `framework/lib/{contract,reconcile,facts,inventory,accounts,typed,check,lock-drift,fleet,home,sections,modules}.nix` | types, pure logic, the builder, the check helper, the path-wise lock comparison |
| `framework/sync-framework-lock.sh` | the lock tool behind `packages.<system>.sync-framework-lock` |
| `framework/home/` | one module per program: mechanism only |
| `framework/system/common/` | modules that also load under system-manager |
| `framework/system/nixos/` | NixOS modules; `desktop.nix`, `audio.nix`, `pam.nix` are capability providers; `accounts.nix` turns `sysMod.accounts` into users |
| `framework/system/optional/` | providers enabled by a flake setting (`agenix.nix`) |
| `framework/adapters/` | translation only: contract wiring, NixOS, Hjem, standalone, system-manager |
| `framework/checks/` | unit checks and the synthetic fleet |
| `users/black/` | `account.nix` (black's identity, the default on every host), `cli.nix` (every host), `development.nix`, `desktop.nix`, `nvim.nix` (gated on `facts.kind`), plus Hyprland and Quickshell sources |
| `hosts/common/` | hardware and values shared by the two reference hosts, including their decisions about black's account (groups, guest password) |
| `hosts/<host>/` | facts, optional report, hostConf, optional per-user override |
| `flake.nix` | inputs, and the `framework` settings: root, inventory, overlays |
| `checks.nix` | the `config` check |
| `overlays/unstable.nix` | `pkgs.unstable.<name>` from the `nixpkgs-unstable` input |
| `docs/spec.md` | the architecture spec (v4) |

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
