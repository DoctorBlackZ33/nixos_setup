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
| String vs path | A path literal carries source-location semantics and is eligible for store copying; a string containing `/home/black/nixos/...` is only text. Convert deliberately with `toString`/`builtins.toPath` where supported. |
| Module file vs module value | `./x.nix` is a path value; `imports = [ ./x.nix ]` asks the module system to import it. A module value can instead be `{ config, lib, ... }: { ... }`. |

## 2. Flakes and command-line lookup

### Flake reference and output selection

| Form | Interpretation |
|---|---|
| `path:/home/black/nixos` | Explicit local flake URI; avoids ambiguity with a bare path. |
| `path:/home/black/nixos#nixosConfigurations.desktop` | URI plus `#` attribute selector; selectors traverse attributes with dots. Quote selectors containing `@`, spaces, or shell metacharacters. |
| `github:owner/repo` / `github:owner/repo/ref` | GitHub shorthand; `ref` can be branch, tag, or revision. |
| `git+https://host/repo?ref=main&rev=...` | Explicit Git transport and query parameters; `rev` pins content, `ref` names the requested ref. |
| `./.` / `path:.` | Local flake path; lock metadata records a content hash/mtime and dirty-tree status as applicable. |
| `#attr` | Output selector shorthand when the flake URI is supplied separately (for example `nix build .#packages.x86_64-linux.default`). In shell, quote `path:/home/black/nixos#homeConfigurations."black@desktop".activationPackage`. |

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
nix flake show --no-update-lock-file --no-write-lock-file path:/home/black/nixos
nix flake metadata --no-update-lock-file --no-write-lock-file path:/home/black/nixos
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/nixos#nixosConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/nixos#homeConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/nixos#modules.homeManager --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/nixos#modules.nixos --apply builtins.attrNames
```

Build without activation or lock writes:

```sh
nixos-rebuild build --flake 'path:/home/black/nixos#desktop' \
  --no-update-lock-file --no-write-lock-file
nixos-rebuild build --flake 'path:/home/black/nixos#laptop' \
  --no-update-lock-file --no-write-lock-file
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".activationPackage'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".activationPackage'
```

Enter the repository's per-system development shell (the `devShells.x86_64-linux.default` output):

```sh
nix develop --no-update-lock-file --no-write-lock-file path:/home/black/nixos
```

For desktop/laptop, activate the matching host and black Home Manager
generation separately. They have independent activation and are not atomic:

```sh
sudo nixos-rebuild switch --flake 'path:/home/black/nixos#desktop' \
  --no-update-lock-file --no-write-lock-file
home-manager switch --flake 'path:/home/black/nixos#black@desktop' \
  --no-write-lock-file
```

Use `laptop` and `black@laptop` on the laptop host. If NixOS activation succeeds
but Home Manager activation fails, the system generation remains active while
the home stays at its previous generation. Run `home-manager` as `black`
without `sudo`.

The Proxmox outputs are different: `system-home-admin` embeds Home Manager
in NixOS. On VM102, `sudo nixos-rebuild switch --flake
'path:/etc/nixos#k3-vm-1' --no-update-lock-file --no-write-lock-file`
also activates admin's home through `home-manager-admin.service`; use
`k3-vm-2` on VM103. There is no standalone admin home output.

## 3. flake-parts semantics

### Module scopes and arguments

`flake-parts.lib.mkFlake { inherit inputs; } module` runs a Nix module system whose final `config.flake` becomes flake outputs. `config` and `options` are the flake-parts module-system state, not NixOS or Home Manager state.

| Scope | Common module arguments | What `config` means | What this repo uses |
|---|---|---|---|
| Top-level flake-parts module | `config`, `options`, `lib`, `inputs`, `self`, `getSystem`, `moduleWithSystem`, `withSystem`; `system`/`pkgs` are not generally available here. | Global flake-parts options, including `config.flake`, `config.perSystem`, `config.systems`, and registries. | All `flake-module.nix` files define registries or outputs here. |
| `perSystem = { system, pkgs, ... }: { ... }` | `system`, `pkgs`, `self'`, `inputs'`, plus module `config`/`lib`; only explicitly named function parameters are passed. | The current system's per-system option namespace. | `system/modules/flake-module.nix` defines `formatter` and `devShells.default`. |
| `withSystem "x86_64-linux" ({ pkgs, system, ... }: expr)` | Per-system context selected explicitly; `pkgs` is the pinned nixpkgs package set for that system. | The selected per-system context while constructing `expr`. | Deployments construct two standalone Home Manager configurations. |
| NixOS module | `config`, `options`, `lib`, `pkgs`, `modulesPath`, and declared special args. | NixOS option tree (`services`, `boot`, `users`, etc.). | VM/Proxmox host entries, `system-*`, `kernel-*`, `account-black`, and `account-admin`. |
| Home Manager module | `config`, `options`, `lib`, `pkgs`, and Home Manager special args. | Home Manager option tree (`home`, `programs`, `myHome`, etc.). | `home-black`, `home-admin`, `preferences-black`, profiles, policies and `home/modules/*`. |

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

The root `flake.nix` declares these inputs. The tracked `flake.lock` pins
their resolved revisions for reproducible recovery installs:

| Input | URL / relation | Consumers |
|---|---|---|
| `nixpkgs` | `https://releases.nixos.org/nixos/26.05/nixos-26.05.6503.21ea275a7c46/nixexprs.tar.xz` | Explicit NixOS and Home Manager constructors; system and home packages. |
| `home-manager` | `https://github.com/nix-community/home-manager/archive/refs/heads/release-26.05.tar.gz`; follows `nixpkgs` | Home Manager flake module, standalone black constructors, and integrated admin NixOS module. |
| `nvf` | `github:NotAShelf/nvf`; follows root `nixpkgs` | Registered editor module and user editor configuration. |
| `nix-cachyos-kernel` | Pinned archive at `dbae8dc454556968710401643aa2c6867d166440.tar.gz` | Retained `kernel-cachy` registry module; none of the current hosts selects it. |
| `flake-parts` | `github:hercules-ci/flake-parts` | `mkFlake` and explicit module registries. |

The root imports the flake-parts module-registry extension, Home Manager's
flake-parts module, then the system modules/accounts/host registries, Home
Manager feature/profile/policy/user registries, and the deployment constructors.
All registry imports are explicit and independent of evaluated configuration.

### Registries and ownership

| Area | Responsibility |
|---|---|
| `system/modules/flake-module.nix` | Registers shared NixOS base, desktop, development, k3s, Tailscale, platform and kernel modules; `system-home-admin` bridges integrated Home Manager to `home-admin`; keeps the formatter and development shell. |
| `system/accounts/` | Registers unchanged immutable `account-black` and reusable `account-admin`; owns OS logins, groups, shells and password hashes, not Home Manager identities. Admin uses a salted initial hash with mutable users on the guests. |
| `system/hosts/vm/` | Registers common VM settings and named desktop/laptop hosts. Both use the unchanged `hardware.nix`, software-rendering settings and NixOS state version `26.05`; only the hostname differs. |
| `system/hosts/proxmox/` | Registers CLI-only `host-proxmox-common` and `host-k3-vm-1`/`host-k3-vm-2`; owns SeaBIOS GRUB, NetworkManager, QEMU agent, native password SSH, locked root, and per-guest generated hardware. |
| `home/modules/` | Registers typed, guarded Home Manager features. `module-set-cli` imports terminal-only modules; full `module-set` adds desktop modules for black. `desktop-tools.nix` contains only graphical packages. |
| `home/profiles/` | Composes base, CLI, desktop and development feature enablement. `profile-cli` reuses base/development, enables nvf and editor variables, and supplies Bash/btop to both users. |
| `home/users/black/flake-module.nix` | Keeps Home Manager target (`black`, `/home/black`, state version `26.05`) separate from personal preferences (editor, Git identity and profiles); these are not the NixOS OS account. |
| `home/users/black/sources.nix` | Centralizes shared Hyprland fragments, Quickshell files and the session startup command. |
| `home/users/admin/flake-module.nix` | Defines `home-admin` (`admin`, `/home/admin`, state version `26.05`) using only `module-set-cli` and `profile-cli`, with no desktop policy/source files or black Git identity. |
| `home/policies/` | Registers role values: floating-toggle chord, Quickshell `SystemClock` precision member, Qt date-time format and bar label, all represented as strings. |
| `deployments/` | Consumes registry entries to construct four NixOS outputs and two independent standalone black Home Manager outputs. The Proxmox outputs include integrated admin Home Manager, Tailscale, and the stock kernel, but not k3s. |

Entries under `flake.modules` are reusable modules, not runnable outputs.
`deployments/` constructs the actual `nixosConfigurations.*` and
`homeConfigurations.*` outputs from them. NixOS outputs own the OS account and
host configuration; Proxmox outputs also integrate admin Home Manager.
Standalone black Home Manager outputs do not read `osConfig` and can be
evaluated or built without a NixOS configuration.

### Policy values and outputs

`myHome.hyprland.floatingToggleChord` is a string emitted into exactly one
floating-toggle binding in `.config/hypr/hyprland.lua`; the shared keybind
fragment no longer defines a competing `SUPER + V` binding. The desktop and
laptop policies set `SUPER + SPACE` and `SUPER + V`, respectively, while other
valid chord strings render directly.

`myHome.quickshell.clockPrecision` is a string naming the actual Quickshell
`SystemClock` precision member, emitted as the QML enum expression. The
independent `myHome.quickshell.clockFormat` string is emitted as a Qt date-time
format. The desktop policy uses `SystemClock.Seconds` with
`yyyy-MM-dd HH:mm:ss`; the laptop uses `SystemClock.Minutes` with
`yyyy-MM-dd HH:mm`. `home/modules/quickshell.nix` renders these values without
mapping them through a finite set of role presets, and the shared shell consumes
the generated `DesktopPolicy.qml`.

| Output | Composition |
|---|---|
| `nixosConfigurations.desktop` | `nixosSystem` with shared graphical VM host, `account-black`, stock kernel, `system-k3s`, and `system-tailscale`; hostname `nixos-desktop`. |
| `nixosConfigurations.laptop` | `nixosSystem` with the same host baseline/account/kernel; hostname `nixos-laptop`. |
| `nixosConfigurations.k3-vm-1` | VM102: `host-k3-vm-1`, `account-admin`, stock kernel, `system-home-admin`, and `system-tailscale`; generated ext4 root UUID `d02e4b1e-0a20-41b1-90b3-708367ee2e93`. |
| `nixosConfigurations.k3-vm-2` | VM103: `host-k3-vm-2`, same account/kernel/services, and its own generated ext4 root UUID `e860c58f-c882-4c97-b224-99b49e1c1fa2`. |
| `homeConfigurations."black@desktop"` | `homeManagerConfiguration` with the same Home Manager target, preferences and source catalog plus `policy-desktop` (`SystemClock.Seconds`, `yyyy-MM-dd HH:mm:ss`, `SUPER + SPACE`). |
| `homeConfigurations."black@laptop"` | Same standalone profile and source catalog plus `policy-laptop` (`SystemClock.Minutes`, `yyyy-MM-dd HH:mm`, `SUPER + V`). |

Desktop/laptop retain their existing graphical VM hardware, packages and
standalone black outputs. All four hosts use the stock kernel; the CachyOS
kernel module/input remains available but unselected. The input declarations
are retained and the tracked lock is shared by both recovery installations.

### Source boundaries

- `system/hosts/vm/hardware.nix`: persistent root/EFI filesystems, systemd-boot,
  virtio modules, QEMU guest service and existing VM variant sizing.
- `system/hosts/proxmox/k3-vm-{1,2}/hardware.nix`: actual generated per-guest
  ext4 root UUID, QEMU profile and initrd modules, explicit `x86_64-linux`.
  Both disks have GPT `sda1` (1 MiB BIOS-grub) and `sda2` (remaining ext4
  root), no swap/ESP; GRUB's whole-disk target is
  `/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0`.
- `home/config/hypr/` and `home/config/quickshell/`: shared compositor and shell
  source; `home/config/hypr/host-vm.lua` retains the VM monitor/gap settings.
- `home/users/black/config/quickshell/`: user-owned QML settings.
- `deployments/`: output composition only; it does not own duplicate host or
  user configuration sources.

Building never activates. Desktop/laptop do not embed black Home Manager
activation, and their compositor/bar checks require a graphical session.
The Proxmox outputs instead autoactivate admin Home Manager at install/boot
and on NixOS rebuild, without a graphical session.

### Proxmox bootstrap and observed recovery

`account-admin` sets Fish, wheel/networkmanager membership, and only a salted
`initialHashedPassword`. The guests explicitly keep mutable users so admin's
`passwd` changes survive rebuilds. Wheel sudo requires the admin password;
native OpenSSH password authentication is enabled, keyboard-interactive
authentication is disabled, root SSH is denied, and root's password is
locked. Never copy the immutable `account-black` policy to these hosts.

At the console, admin runs `sudo tailscale up`, completes the account-owner
authorization, and obtains the address with `tailscale ip -4`. Authorized
peers then use native `ssh admin@TAIL_IP` with the admin password. No auth
key, Tailscale SSH, automatic enrollment, or cluster join is configured;
the `k3-` names do not enable a k3s service. Rotate the bootstrap password
with `passwd` before relying on the system.

Recovery on 2026-10-24 confirmed both original 64 GiB disks were blank before
GPT/BIOS-grub/ext4 preparation. Original RAM `/etc/nixos` sources were
archived outside the repo. Hypervisor snapshots preserve that original state:
`rpool/data/vm-102-disk-0@pre-nixos-recovery-20261024` and
`rpool/data/vm-103-disk-0@before-nixos-recovery-20261024`.
They are not installed-system backups.

Both guests subsequently booted their actual ext4 roots with the ISO
detached and Proxmox disk-only boot selected. Console password login and
independent password-only admin SSH/sudo were exercised; integrated Home
Manager succeeded, CLI/editor/compiler tools were present, and Tailscale
and the QEMU agent were active. Both actual closures had zero
Hyprland/Quickshell matches. Tailscale intentionally remained `NeedsLogin`,
without tailnet addresses, so tailnet SSH is not yet verified.
See [the README guest operations and evidence](README.md#cli-only-proxmox-guests)
for the per-guest UUIDs, observed DHCP addresses, tool smoke checks, and
console authorization procedure.

## 5. Further reference

- [Vimjoyer Nix index](https://www.vimjoyer.com/nix): compact examples for flakes, flake-parts, shells, and dendritic module layouts; examples here are adapted only as cross-reference, while repository paths and behavior above are independently verified.
