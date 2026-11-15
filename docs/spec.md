# NixOS infrastructure architecture: spec

Status: v4, 2026-11-15. Supersedes v3 (`nixos-architecture-spec-v3.md`) and, through it, draft v2 (`nixos-architecture-spec.md`); both are kept outside the repository and no longer edited.
Reference implementation: `/home/black/experimental` (`AUDIT.md` there records what changed and what was run). This file is `docs/spec.md` in that repository and, from v4 on, the authoritative version: the spec is changed there, in the same commit as the code it describes.

Principle: **Mod is general, Conf is specific.** General modules live in a framework flake. Specific values live in a config flake. A typed contract says what users and hosts need and what hosts supply; one pure reconcile step compares them; adapters turn the result into NixOS systems, system-manager configs or Hjem standalone configurations.

Three corollaries that v2 left implicit:

1. **Adapters translate, providers fulfil.** An adapter never knows a capability by name.
2. **The inventory is data.** How outputs are built is framework code; `deployments.nix` only says who runs where.
3. **What a host is selects how it is built.** The `managed` fact picks the adapters; nothing repeats that choice.

---

## 1. Goals

1. Write all config as pure Nix with as few NixOS-class dependencies as possible.
2. Keep user space (home) and root space (system) apart. The only link between them is the declared contract (section 7).
3. The user layer must work on NixOS and, without changes, on non-NixOS hosts.
4. The repo grows into a multi-host, mostly-server infrastructure repo: 10+ machines, workstations and servers, NixOS and non-NixOS, several architectures.
5. Secrets use agenix + agenix-rekey, with a hardware key and 1Password (section 11).
6. **Any host evaluates on any machine.** No module needs a build during evaluation (R9), so an x86_64 laptop can check an aarch64 server.
7. **Adding a host touches `hosts/<host>/` and one line of `deployments.nix`.** No check, list or adapter is edited by hand, and no account is written again: a user brings their own (section 10.2).

## 2. Non-goals (for now)

- One flake per program or per feature.
- Installing packages through distro package managers, pip or npm. Packages are Nix derivations everywhere (R5). A distribution may still *supply a capability* (a compositor, a PAM service); the host then declares it (section 7.3).
- A nixpkgs per host or per deployment. Every host follows one channel; newer software comes in as single packages (section 4, Q7).
- Writing our own Arch/Debian system adapters: use system-manager.
- Adopting clan now (section 10.4).
- A Kubernetes / GPU-cluster abstraction.
- Our own DAG engine or settings-merging engine (section 9).
- A generic contract framework in the style of RFC 189. That RFC is still open and its author calls the generic machinery unjustified; we keep one table of capability kinds and plain provider modules.
- macOS. Nothing here prevents it, nothing here supports it.

## 3. Backbone: what each tool does here

| Tool | Role in this repo | Limits (verified 2026-11-15) |
|---|---|---|
| Flakes | Pinned inputs; outputs per deployment | A `path:./framework` input needs its files git-tracked; a changed input list needs `nix flake update framework`. The subflake keeps its own lock, which `nix flake update` in the root does not touch |
| nixpkgs | One release branch (`nixos-26.05`) for every host and user; single newer packages from `nixpkgs-unstable` as `pkgs.unstable.<name>` | A branch reference moves only when `nix flake update` runs. system-manager's release branch must match the release |
| flake-parts | Structure; the framework ships a flake module that turns inventory + tree into outputs | `perSystem` is for packages and checks. Which nixpkgs platform a host uses follows `facts.platform` |
| Hjem | Writes each user's files and packages. NixOS module for hosts we manage; `hjem standalone switch` everywhere else | The standalone manifest (version 3) has files and packages but no field for environment variables, and no secrets. It keeps generations, removes stale links and moves a file in its way to `.backup-<name>` |
| system-manager | Applies a subset of NixOS modules on non-NixOS distros | Its release branch must match the nixpkgs release. Subset only: no `time`, `hardware`, `xdg`, `fonts.packages`, `networking.hostName`, kernel, bootloader; its firewall module is a mock |
| nixos-facter | Generates `facter.json`; the framework derives facts from it | Needs root. Hardware only |
| agenix + agenix-rekey | Secrets: encrypt once to master keys, rekeyed per host | The rekey module refuses to evaluate without a master identity, so it is imported only once secrets are configured. NixOS only |
| nix-wrapper-modules | Possible extra adapter for programs configured by flags or env vars | Not implemented |

## 4. Repository layout

Two flakes in one repo. The framework is a subflake now and can move to its own repo once stable.

```
.
├── flake.nix                       # config flake: pins inputs, sets the package policy, imports the framework flake module
├── checks.nix                      # checks about this configuration (checks.<platform>.config, section 12)
├── deployments.nix                 # the inventory (pure data)
├── docs/spec.md                    # this specification
├── overlays/<name>.nix             # nixpkgs overlays listed in framework.overlays; unstable.nix: pkgs.unstable
├── users/<user>/default.nix        # userConf (homeMod class); may import sibling profile files
├── users/<user>/account.nix        # who the user is as a login, the default on every host (pure data)
├── hosts/<host>/facts.nix          # what the host is (pure data)
├── hosts/<host>/facter.json        # optional hardware report; fills gaps in facts.nix
├── hosts/<host>/default.nix        # hostConf for NixOS and system-manager hosts
├── hosts/<host>/provides.nix       # manual hosts, optional: capabilities supplied by hand
├── hosts/<host>/users/<user>.nix   # optional host-specific user override (homeMod class)
├── secrets/<name>.age              # encrypted to the master keys only
├── secrets/rekeyed/<deployment>/   # agenix-rekey output, committed
├── secrets/identities/             # YubiKey identity stubs (no private key material)
└── framework/
    ├── flake.nix                   # names every dependency the adapters and modules need
    ├── flake-module.nix            # flake-parts module for config flakes
    ├── sync-framework-lock.sh      # re-locks framework/flake.lock from the root lock (packages.<system>.sync-framework-lock)
    ├── lib/capabilities.nix        # the one table of capability kinds
    ├── lib/contract.nix            # requires / provides / facts types, derived from the table
    ├── lib/reconcile.nix           # pure merge + reconcile
    ├── lib/facts.nix               # facts.nix + facter.json -> one typed value
    ├── lib/inventory.nix           # schema of deployments.nix
    ├── lib/accounts.nix            # account type: the user's file and the host's options
    ├── lib/typed.nix               # plain data -> typed value; unknown fields fail, naming the file
    ├── lib/check.nix               # mkCheck: a check made of named conditions
    ├── lib/lock-drift.nix          # the two lock files compared path by path (config check, lock tool)
    ├── lib/fleet.nix               # inventory + tree -> outputs and checks
    ├── lib/home.nix                # the one instantiation of the homeMod class
    ├── lib/sections.nix            # named, ordered text sections
    ├── lib/modules.nix             # directory -> module set
    ├── home/<program>.nix          # homeMod modules, one file per program
    ├── system/common/<feature>.nix # system modules valid on NixOS and system-manager
    ├── system/nixos/<feature>.nix  # NixOS-only system modules, including providers
    ├── system/optional/<name>.nix  # providers switched on by a flake setting (agenix)
    ├── adapters/                   # contract wiring, nixos, nixos-users, hjem, standalone, system-manager
    └── checks/                     # unit checks and a synthetic fleet
```

`home/`, `system/common/` and `system/nixos/` are discovered from their directories by one function; a file added there is part of the framework. `system/optional/` is not discovered: its modules are imported by the fleet builder when their flake setting is present.

Why split Mod from Conf, and not home from system: reconcile needs both sides in one evaluation.

Dependencies: the framework flake declares every input its adapters and modules need. The config flake declares the same inputs and makes the framework follow them, so **the root lock file alone decides what is deployed**. The framework's own lock is used only when its checks run alone, and it must agree with the root lock at every input path the two share. `framework/lib/lock-drift.nix` decides that: it resolves each node's input references and `follows` from both locks' roots, compares the pins along the same dependency path, treats `path` nodes as equal in type only (their input edges are still compared), and tolerates cycles. Renamed nodes therefore do not count as drift, while a pin reached through a different path does. The module exports the comparison (`drifted`) and its resolver (`resolvePath`); the config check uses both and the lock tool uses `drifted`, so the check and the tool cannot disagree. `nix run .#sync-framework-lock` (`framework/sync-framework-lock.sh`, exported as `packages.<system>.sync-framework-lock`) runs `nix flake lock --reference-lock-file ../flake.lock --output-lock-file flake.lock` inside `framework/`, which forwards the root's complete input graph; Nix drops the inputs the framework does not use. The output file is named explicitly because the reference flag only selects the lock to read: when the graph already matches, Nix would exit without writing, leaving a missing or stale file. The tool then runs the comparison and exits non-zero, listing the input paths that disagree; this postcondition, not the re-lock, is what guarantees the result. The config flake additionally runs the framework's checks against its own lock.

**One nixpkgs.** Every host and every user is built from one nixpkgs, `github:NixOS/nixpkgs/nixos-26.05`. It is a branch reference: the lock pins a revision, and `nix flake update nixpkgs` moves every host at once. Moving to the next release changes this reference and system-manager's release branch together. There is no separate selector: every delivery path is built from the framework's own `nixpkgs` input, which the config flake makes follow its `nixpkgs`, so the root lock decides. That holds only while every input with a `nixpkgs` input keeps following the root's; an input that stops following (say `system-manager.inputs.nixpkgs` pointed elsewhere) would diverge without a word, so the config check resolves every `nixpkgs` edge in the root lock and fails, naming the input paths, when one leads to another node (section 12). The guarantee is one identical input, not identical content: `.path` and `outPath` are metadata and do not prove that two package sets come from the same source, and nothing hashes content at evaluation time (R9). A second input, `nixpkgs-unstable`, is reachable only as `pkgs.unstable.<name>`, through the overlay in `overlays/unstable.nix`: a profile or host that needs a newer program takes that one package from it. No host and no whole profile is built from unstable; mixed channels would need a nixpkgs per deployment and a matching system-manager release for each (Q7).

**Package policy.** Overlays and nixpkgs `config` are set once, in the config flake, as `framework.overlays` and `framework.nixpkgsConfig`, and reach all three paths. A NixOS system gets them as `nixpkgs.overlays` and `nixpkgs.config`; its Hjem users get the system's `pkgs`. A system-manager system gets the config as `nixpkgs.config` and the overlays as the `overlays` argument of `makeSystemConfig`, not through its `nixpkgs.overlays` option: that option is typed `listOf anything`, and the wrapping it applies breaks an overlay that reads `prev`. Standalone users are evaluated with one package set per platform, built from the same nixpkgs with the same overlays and config. A user's profile therefore sees the same packages whichever adapter delivers it.

**Updating** happens in the root of the repository:

```sh
nix flake update [<input>]       # moves flake.lock only
nix run .#sync-framework-lock    # re-locks framework/flake.lock from flake.lock; fails on an input path that disagrees
nix flake check …                # section 12; the config check fails on lock drift
```

A config flake passes its own inputs or other values to hostConf and userConf with `framework.moduleArgs`, under names of its choice (`{ flakeInputs = inputs; }`). Names the framework already provides (`inputs`, `pkgs`, `facts`, `framework`, …) are rejected.

## 5. Layers

| Layer | Kind | Holds | Module class | Lives in |
|---|---|---|---|---|
| homeMod | general | Program modules: mechanism only | `homeMod` (own class) | framework |
| systemMod | general | Root config and capability providers | `nixos`; the portable subset also loads under system-manager | framework |
| userConf | specific | One user's values: profiles, preferences, sources, looks; plus `account.nix` | `homeMod`, plus data | config |
| hostConf | specific | One host's values, plus `facts.nix` | `nixos` or system-manager, plus data | config |

Promotion rule: anything specific to one user or one host stays in its Conf. Once a second user or host needs it, move it into a Mod that exposes options, and leave only the values in Conf.

**R10** makes the rule checkable. A general module contains:

- no value that identifies a person, host, location or checkout (names, paths, e-mail, time zone of a place);
- no taste: colours, fonts, key chords, aliases, flags that change a tool's behaviour. An option for them is fine; its default is "off" or the tool's own default;
- defaults only where they are neutral policy for a *kind* of machine (a server defaults to UTC and networkd) and can be overridden without `mkForce`.

Servers are built from systemMod + hostConf alone; their user list can be empty, and such a host carries no Hjem at all.

### 5.1 System modules by class

`lib.mkIf false { some.option = …; }` still fails when `some.option` is not declared, so a NixOS-only module cannot be imported into a system-manager evaluation and gated there. Therefore:

- `system/common/` holds modules that only use options both evaluations declare (today: base packages, `nix.settings`).
- `system/nixos/` holds everything else, including all capability providers.
- The NixOS adapter imports both sets, the system-manager adapter imports `common` only.

Which set a module belongs to is decided by where the file lives.

### 5.2 Machine kind

Every host states exactly one `kind`: `workstation` or `server`. General modules gate on it; it is a closed enum, so a typo fails. Free-form `tags` exist for user and host configuration; the framework does not interpret them.

## 6. Evaluation model

Each NixOS host is one lazy evaluation; homeMod is a submodule inside it. On every other host the user layer is evaluated on its own. Both go through one function (`lib/home.nix`), so they get the same modules and the same arguments: `pkgs`, `facts`, `inputs` (the framework's), `framework`, `secretsDirectory`, and `framework.moduleArgs`. `pkgs` carries the package policy (section 4) on both paths: a NixOS user gets the system's `pkgs`, a standalone user the package set of the host's platform, built from the same nixpkgs, overlays and config.

- **NixOS:** `hjem.users.<user>.homeMod` is a `types.submoduleWith { class = "homeMod"; … }`; the deployment adds `users/<user>` and `hosts/<host>/users/<user>.nix` as imports.
- **Elsewhere:** `lib.evalModules` with the same class, arguments and module list.

Rules:

- **R1. `imports` never depend on the `config` of the evaluation they belong to.** They may depend on data fixed before that evaluation starts: the inventory (users present or not), host facts, the module class, and flake-level settings (`framework.secrets`).
- **R2. Data flows one way per kind.** Facts flow host → user. `requires` flows user → system. `provides` flows system → reconcile only.
- **R3. homeMod never reads NixOS options or `provides`.** It may read `facts`, its own options and its arguments. The one thing it learns from the system is where secrets appear (`secretsDirectory`).

Module-system traps met in practice (details in the repository's `reference.md`):

- Hjem builds the type of `hjem.users` from `hjem.extraModules`. A module that sets `extraModules` *and* reads `hjem.users` sees an empty user set. Registration and reading live in separate modules.
- `lib.optional cond x` or `map f (attrNames …)` in a definition set forces `cond` while definitions are collected. Anything derived from the user layer goes behind `lib.mkIf` or is the value of an option.

## 7. Contract

### 7.1 `requires`: what modules need from the host

Emitted by homeMod modules, by userConf, and by system modules or hostConf for things the system itself needs (a workstation that wants audio whoever logs in). It lists **capabilities, not packages** (R4).

```nix
requires = {
  services.<name>  = { };                    # system service, e.g. services.hyprland
  pam.<service>    = { };                    # e.g. pam.hyprlock
  portals.<name>   = { };                    # e.g. portals.gtk
  secrets.<name>   = { mode = "0400"; };     # never the value
  facts."<path>"   = { };                    # e.g. facts."gpu.vendor"
};
```

Every entry has `required = true` by default; `required = false` turns a miss into a warning. All kinds have the same shape, so merging, optionality and messages are one code path.

The kinds are one table (`lib/capabilities.nix`); types, merging and reconcile derive from it. Capability *names* are open: a new name needs only a provider. A new *kind* is one table entry plus a provider.

Threshold for a new kind (changed from v2, which asked for two consuming modules): one real consumer **and** one provider that actually fulfils it, with a check covering both. v2's `udev.rules` and `setuid` had neither and were removed.

### 7.2 `facts`: what the host is

Fixed data, never derived from homeMod (R2).

```nix
facts = {
  name = "desktop";            # the deployment name; set by the framework
  hostName = "nixos-desktop";  # network name
  platform = "x86_64-linux";
  managed = "nixos";           # nixos | system-manager | manual
  kind = "workstation";        # workstation | server
  tags = [ ];
  location = null;
  virtualisation = "kvm";      # null on bare metal or when unknown
  gpu = { vendor = "amd"; vulkan = null; };   # amd | intel | nvidia | virtual | null
  displays = [ { width = 2560; height = 1440; refresh = 144; } ];   # refresh may be null
  hostKey = null;              # SSH host public key; recipient of this host's secrets
  extra = { };                 # free-form; not validated
};
```

- `facts.nix` is hand-written; `facter.json`, when present, fills in `platform`, `virtualisation`, `gpu.vendor` and `displays`. Hand-written values win.
- **`null` means unknown.** There are no invented defaults, so a requirement on a fact can fail. A fact satisfies a requirement when it is neither `null`, `false`, nor empty.
- Facts are evaluated through one type and handed to every adapter as the same value.
- `hostName`, `managed` and `kind` are mandatory; `platform` is mandatory unless a report supplies it.
- **Facts are authoritative.** Inside a system evaluation they are read-only, and the system's host name and platform are asserted equal to them. The inventory validates and files checks by facts, so a system may not disagree.

### 7.3 `provides`: what the system supplies

`provides.<kind>.<name>` is a boolean.

- **NixOS:** each *provider module* reads the merged requests (`contract.wanted`), enables what it offers, and reports `provides` from the resulting config. The desktop provider sets `programs.hyprland.enable` when a compositor is requested and reports `provides.services.hyprland = config.programs.hyprland.enable`; a portal counts only when the portal service is enabled *and* the backend is installed.
- **system-manager:** the portable module set contains no providers today, so what the distribution supplies is declared in that host's hostConf (`contract.provides.services.hyprland = true;`). This is an operator's statement, not something the build verifies.
- **Manual hosts** declare the same in `hosts/<host>/provides.nix`; without the file nothing is provided.
- Secrets can be provided only by the NixOS provider; declaring them elsewhere is rejected.

A provider decides *where* it offers something. The desktop and audio providers have `sysMod.desktop.enable` / `sysMod.audio.enable`, defaulting to "on workstations". That is how a host refuses: a desktop user placed on a server gets a contract error naming the user, instead of a compositor being installed there; and a headless audio server opts in with one line.

### 7.4 Requests and reconcile

Requirements are never merged anonymously. They are kept by source:

```nix
contract.requests = {
  system       = <requires>;   # system modules and hostConf
  "user alice" = <requires>;   # one entry per user
};
```

```nix
merge     : requests -> wanted      # wanted.<kind>.<name> = { required; sources; <parameters>; }
reconcile : { host, requests, provides, facts }
            -> { errors; warnings; forSources : [ source ] -> { errors; warnings; }; }
```

- One requester needing a capability makes it required for the host.
- Requesters that disagree on a parameter (a secret's mode) are an error naming each of them.
- Every message names the capability, every requester and the host:
  `service 'hyprland' is requested by user carol but host 'nas' does not provide it`.
- A missing required capability or fact is an error; a missing optional one is a warning.
- **Who is judged where.** A system evaluation judges everyone evaluated inside it: itself and, on NixOS, every Hjem user. Errors become one failing assertion, warnings go to `warnings`.
- **Standalone users** (on system-manager and manual hosts) are evaluated outside any system. All users of the host are reconciled together, then each user's configuration takes the verdict for the findings it is involved in (`forSources`). Another user's unmet request does not block them; a conflict they are part of does. Errors `throw` when the configuration is evaluated, warnings go through `lib.warn`.
- A system-manager evaluation receives its standalone users' requests as data so that providers can react to them, but it does not fail because of them. Otherwise one user's unmet request would stop the system and every other user of that host.
- `reconcile` is pure and takes typed values only. Hand-written data goes through the same types first, so an unknown *kind* or field fails. Capability names and `facts.extra` are open and are not checked for typos.

## 8. Adapters (in the framework flake)

All glue lives in adapters. A homeMod evaluation produces only this interface:

```nix
{
  files       = { "<path relative to $HOME>" = { text | source }; };   # no absolute paths, no `..`
  packages    = [ drv ];
  environment = { NAME = "value"; };
  requires    = { … };
}
```

| Adapter | Selected by | Output | Notes |
|---|---|---|---|
| NixOS | `managed = "nixos"` | `nixosConfigurations.<name>` | Imports `system/common` + `system/nixos` + hostConf, the package policy, and each deployed user's account file as `sysMod.accounts.<user>` definitions (section 10.2). With users: imports Hjem, maps `files`/`packages`/`environment` onto it, adds one request source per user, and asserts each deployed user has an account |
| system-manager | `managed = "system-manager"` | `systemConfigs.<name>` | Imports `system/common` + hostConf; gets the package policy, the overlays as `makeSystemConfig`'s `overlays` argument (section 4). Users are delivered standalone; their account files are typed but not applied, because logins there belong to the distribution |
| Standalone | users on any host that is not NixOS | `hjemConfigurations."<user>@<name>"` | Exactly the value `hjem standalone switch` consumes: `{ manifest = { version = 3; files = [ … ]; }; packages = [ … ]; }`, with packages from the host platform's package set under the package policy. `environment` is written to `~/.config/environment.d/`, which systemd user sessions read; shells that do not are handled by their own module (fish) |
| wrapper | nothing yet | none | Not implemented |

Activation tools are exported at the locked revisions:

```sh
nix run <flake>#system-manager -- switch --flake <flake>#<name> --sudo
nix run <flake>#hjem -- standalone switch --flake <flake> --flake-attr 'hjemConfigurations."<user>@<name>"'
nix run <flake>#agenix -- rekey -a          # with secrets enabled
```

The same `hosts/<host>/users/<user>.nix` is imported on both user paths (R7); it is optional.

## 9. Config generation inside homeMod

No custom merge engine, and **no evaluation-time builds (R9)**.

- **Structured formats (TOML, YAML, INI, git config):** a `settings` option typed with `(pkgs.formats.<format> { }).type`; the file is `source = format.generate "<name>" cfg.settings`. Never `builtins.readFile` a generated file: that is import-from-derivation and makes a foreign-architecture host impossible to evaluate. Defaults are values, never a static file concatenated with user settings. The format type validates structure, not the application's key names; where upstream offers a config check, add one.
- **Module options are typed.** `fish.aliases` is `attrsOf str`; a misspelled *option* fails. A blanket `settings = attrsOf anything` on every program is not allowed. (Hyprland's `settings` is deliberately free-form: it is passed to `hl.config` as Lua.)
- **Lua:** `lib.generators.toLua`, plus `lib.generators.mkLuaInline` for raw expressions.
- **Text assembled by several modules (fish config, Hyprland Lua, QML):** *named sections*, `sections.<name> = { enable; order; text; }`, rendered in ascending `order`, ties broken by name. `order` uses the `lib.mkOrder` scale (500 before, 1000 default, 1500 after). A section can be replaced (`lib.mkForce`) or switched off (`enable = false`) by name from a host override. This replaces v2's "`types.lines` + `mkOrder`" for this case: `types.lines` cannot address one contribution, and it breaks ties by module order, which is not stable. Plain `types.lines` remains fine for text with one owner.
- **Named dependencies** (rare): `lib.toposort`.

## 10. Deployments

### 10.1 Names

| Term | Meaning | Example |
|---|---|---|
| deployment name | key in `deployments.nix`; output and check name; `facts.name`; directory under `secrets/rekeyed/` | `desktop` |
| host directory | directory under `hosts/`; defaults to the deployment name | `hosts/desktop` |
| host name | `facts.hostName`, the network name | `nixos-desktop` |
| user | directory under `users/`; on NixOS also the account name | `black` |

### 10.2 The inventory

`deployments.nix` is plain data and typed:

```nix
{
  desktop = { users = [ "alice" ]; };
  nas     = { };                                   # no users
  imac    = { users = [ "alice" ]; homes.alice = "/var/home/alice"; };
  work    = { host = "work-laptop"; users = [ "alice" ]; };
}
```

| Field | Default | Meaning |
|---|---|---|
| `host` | the deployment name | host directory |
| `users` | `[ ]` | user directories |
| `homes.<user>` | `/home/<user>` | home directory for standalone delivery. Not allowed on NixOS hosts, where the account defines it |

There is no `adapter`, no `system` and no nixpkgs field: what a host is lives in its facts, and every deployment is built from the one nixpkgs (section 4).

**Accounts.** On a NixOS host, listing a user in `users` also gives them a login there. The account is split by who decides:

| Decided by | Where | What |
|---|---|---|
| the user | `users/<user>/account.nix`, plain data | who they are: `description`, `uid`, `shell` (`bash`, `fish` or `zsh`), `authorizedKeys`, `hashedPassword`, `hashedPasswordFile` |
| the host | `sysMod.accounts.<user>` in `hosts/<host>/default.nix` | what they may do there: `groups`; extra `authorizedKeys`; a password for a throwaway guest; an override of a single value such as `shell` |

- The account file is the shared default wherever the inventory deploys the user. On a NixOS host the fleet builder hands it to the system as `sysMod.accounts.<user>` definitions: single values yield to the host's own, lists add up, so the host's keys are added to the user's. Accounts are created only on NixOS hosts. On system-manager and manual hosts the login belongs to the distribution and is left untouched: the file is type-checked there and a mistake in it is refused, but no login is created.
- The uid lives in the account file, so by default a user has the same uid on every host and files keep their owner when they move between hosts (Q13). It is a default, not a guarantee: a host may override any single value, the uid included (an override to another uid evaluates). The reference configuration's `config` check compares only the identity fields, uid, description and shell, across hosts; credentials and keys are not compared. A shell compares by its identity, not by its package name: `shell = "bash"` installs `bashInteractive`, whose package name `bash-interactive` counts as `bash`.
- Group membership grants rights on one machine, so only that machine grants it: `groups` in an account file is rejected, as is `services` (a user asks for services through `requires`, section 7.1) and any other field the account type does not know. The error names the file and the field.
- A host may declare accounts of its own that belong to no user directory, such as an administrator login. A deployed user with neither an account file nor a host account fails the NixOS adapter's assertion (section 8), which names user and host.
- An account file is data read before any evaluation, like the inventory, and not part of the homeMod evaluation. R2 and R3 stand: the system learns about a user from `requires` and from this file, and the user layer learns nothing from the system.

### 10.3 Outputs and checks

| `facts.managed` | System output | Users |
|---|---|---|
| `nixos` | `nixosConfigurations.<name>` | inside the system, through Hjem |
| `system-manager` | `systemConfigs.<name>` | `hjemConfigurations."<user>@<name>"` |
| `manual` | none | `hjemConfigurations."<user>@<name>"` |

`systems` is derived from the hosts' platforms. Every deployable thing is its own check, built for the host's own platform: `checks.<platform>."nixos-<name>"` (the system toplevel), `"system-<name>"`, `"home-<user>@<name>"`. The config flake adds `checks.<platform>.config` about its own configuration (section 12).

The builder rejects, with a message that lists the valid names where that helps: an unknown host or user; a user listed twice; `homes` for an unlisted user, a relative home, or `homes` on a NixOS host; a missing `default.nix` on a managed host or a superfluous one on a manual host; a `provides.nix` on a managed host; secrets declared on a manual host; a misspelled inventory field; two deployments with the same host name; `moduleArgs` that shadow framework arguments; an account file that sets `groups`, `services` or a field the account type does not know, on every kind of host and with the file named. On NixOS it also asserts that every deployed user has an account, even a user whose Hjem configuration is disabled: switching the user layer off does not waive what the deployment requires.

The framework's flake module refuses two configurations before it exports any host. Check platforms come from the flake's `systems` list, which defaults to the fleet's platforms, so either would let `nix flake check` report success while running no check for the hosts concerned:

- **An empty inventory.** There is no deployment, so no platform and no check at all, the config check included.
- **A `systems` list that omits a deployment's platform**, for example one forced to `[ ]` or to another architecture only. Additional platforms are allowed.

Rolling out starts with `nixos-rebuild --target-host` (Q3).

### 10.4 Why not clan (yet)

Clan's inventory keeps per machine `tags`, `machineClass`, `deploy.targetHost`, `description`; roles belong to service instances, not machines. We keep the same split (machine properties in facts, including `tags`; no machine-level roles), so moving later is mechanical. Clan itself brings its own secrets, networking and deployment tooling, which the current fleet does not need.

## 11. Secrets

Implemented for NixOS hosts; opt-in.

- **Tools:** agenix + agenix-rekey, `storageMode = "local"`: rekeyed copies are committed under `secrets/rekeyed/<deployment>/`.
- **Enabling:** `framework.secrets = { directory = ./secrets; masterIdentities = [ … ]; extraEncryptionPubkeys = [ … ]; }` in the config flake. Until then no agenix module is imported, and a requested secret is an ordinary contract miss (error if required, warning if optional).
- **Master keys**, in order:
  1. **YubiKey** via age-plugin-yubikey, in `masterIdentities`; its identity stub goes in `secrets/identities/`.
  2. **1Password SSH key** via age-plugin-1p: a plain SSH public key in `extraEncryptionPubkeys`. It cannot be an equal master, because rage cannot combine `-j` plugins with identities.
  3. **Offline age key** stored as a 1Password document: last resort.
- **Targets:** every NixOS host is a recipient through its SSH host key, stated as `facts.hostKey`. Without it agenix-rekey uses a placeholder and warns.
- **Provider** (`system/optional/agenix.nix`): for each requested secret `<name>` with a file `secrets/<name>.age`, it declares `age.secrets.<name>` with the requested mode and reports `provides.secrets.<name>`. A requested secret without that file stays unprovided.
- **One reader per secret.** The owner is the user who asked, or root when the system asked. With the provider enabled, a second requester is an error whether or not the ciphertext exists yet: give each consumer its own secret. A system service running as another account sets the owner in its own module.
- **Interface:** modules request by name and get a **path**: `config.secretPath "<name>"`, i.e. `/run/agenix/<name>` on NixOS. The provider asserts that the path is not moved. On a host without a backend `secretPath` throws. Secret values never enter the Nix store (R8).
- **Operator tools:** `nix run .#agenix -- edit secrets/<name>.age`, `nix run .#agenix -- rekey -a`.
- **Runtime:** hosts decrypt at activation with their own key. The YubiKey is only needed to edit or rekey.
- **Not covered:** standalone and system-manager hosts have no secrets backend (Q6). Generated secrets (agenix-rekey generators) are available through the upstream options but have no contract support yet.
- **Known exception to R8-in-spirit:** a throwaway VM may carry a password hash in the store (`hashedPassword`, set by that host in `sysMod.accounts.<user>`); real hosts use `hashedPasswordFile` from a secret.

## 12. Testing

Decided at evaluation time unless stated otherwise. The test run is:

```sh
nix flake check --no-build --all-systems --no-update-lock-file --option allow-import-from-derivation false <flake>
```

for the config flake, which also runs the framework's checks against its lock. `--no-update-lock-file` makes the run fail when a lock would have to change, instead of completing the lock silently.

- **Framework unit checks:** the flake module's refusals of an empty inventory and of a `systems` list that omits a deployment's platform (`flake-inventory`); the path-wise lock comparison on fixture locks: the same graph, renamed nodes, follows, cycles, a stable pin borrowed from the root's unstable input, and transitive drift (`lock-graph`); reconcile (clean, required, optional, several requesters, conflicting parameters, false facts, per-source verdict), contract types (including rejected kinds and fields), facts (typing, report mapping, precedence), sections, and one check per homeMod module enabled on its own.
- **Synthetic fleet:** a config tree inside the framework with 13 hosts across workstation/server × NixOS/system-manager/manual × two architectures, built by the same code as a real config flake. It asserts behaviour, not just success: what reaches Hjem and the standalone manifest; that a server stays headless; that an ungated desktop user is refused on all three host types with a message naming user and host; that disabling a user's Hjem configuration does not waive the account the deployment requires; that inventory and host mistakes are rejected; that a requested secret becomes an agenix secret with the right owner and mode. `fleet-accounts`: identity comes from the user's account file and, where no host overrides it, is the same on every host; groups come only from the host; user and host keys add up; a host can override a single value and keep accounts of its own; an undeployed user gets no account; an account file with `groups` or a misspelled field is refused, naming file and field, on a NixOS host and on a host without a system evaluation. `fleet-packages`: an overlay and a nixpkgs `config` reach a NixOS system, the users inside it, a system-manager system and standalone users on system-manager and manual hosts, and the same deployments without them install neither.
- **One build-time check:** the rekeyed copy of a fixture secret decrypts with the fixture host key.
- **Config checks:** one check per deployment (section 10.3); without `--no-build` they build every system toplevel. The config flake's `checks.nix` adds `checks.<platform>.config`, which looks at the real configuration instead of fixtures: the framework's lock agrees with the root lock at every shared input path; every input takes nixpkgs from the root, that is, every node reachable from the root lock that has an input named `nixpkgs` resolves it, through `follows` and node references, to the node the root's own `nixpkgs` resolves to, and a failure names the input paths (`different at: system-manager/nixpkgs`); `black` has the same uid, description and shell on every host (credentials and keys are not compared); `pkgs.unstable` is newer than the base on every host and reaches the users inside NixOS; the server stays headless; the graphical layer is delivered on the workstation only; no contract assertion fails.
- A check fails with the name of the condition that broke. The condition checks of both flakes (`config` and the framework's) are built with one helper, `mkCheck` (`lib/check.nix`).

What this does not prove: that a system boots, that an activation succeeds on a real machine, or that a capability declared by hand on a non-NixOS host really exists.

## 13. Rules summary

- R1. `imports` never depend on the config of their own evaluation; they may depend on the inventory, facts and flake settings.
- R2. Facts flow host → user; `requires` flows user → system; `provides` flows system → reconcile.
- R3. homeMod never reads NixOS options or `provides`.
- R4. `requires` lists capabilities, never packages.
- R5. Packages are Nix derivations on every host.
- R6. Hard requirement → error (assertion or throw); optional → warning.
- R7. Host-specific user overrides are homeMod files that both user paths import.
- R8. Secrets are runtime paths, never values in the store.
- R9. No evaluation-time builds: never read a generated file back during evaluation.
- R10. General modules carry no identifying value and no taste; defaults are neutral and overridable (section 5).
- R11. Adapters translate; provider modules fulfil and report. An adapter names no capability.
- R12. Specific data is typed: facts, provides, account files and the inventory fail on unknown fields and kinds, and the inventory on unknown hosts and users.
- R13. Facts are authoritative: a system may not contradict them.
- R14. One nixpkgs and one package policy (`framework.overlays`, `framework.nixpkgsConfig`) for NixOS systems, system-manager systems and standalone users; newer software enters as single packages, never as a second channel (section 4).
- R15. Who a user is lives in their account file, the default on every host they are deployed to; a host may override a single value, and what the user may do there (`groups`) is that host's decision (section 10.2).

## 14. Build order and status

1. **NixOS only.** Done: reference workstation and server; four layers; kinds `services`, `pam`, `portals`, `secrets`; facts.
2. **Facts + reconcile.** Done: `facter.json` feeds facts; reconcile with provenance wired to assertions and warnings.
3. **Off NixOS.** Implemented. system-manager configs and standalone configurations evaluate and build for fixture hosts; `hjem standalone switch`, stale-link removal and rollback were run in a sandbox home. Not yet run on a real non-NixOS machine.
4. **Secrets.** Implemented for NixOS; the fixture went through the real `agenix rekey` and decrypts. Not yet used with real keys, and activation on a running host was not observed.
5. **Scale out.** Inventory validation, per-deployment checks and the fleet tests are in place; v4 adds account files, one package policy, an updatable nixpkgs and the config check. Next: deployment targets in the inventory and lint checks, then real hosts and a rollout tool (Q3).

## 15. Open questions

- **Q1–Q2, Q5.** Closed (Hjem standalone exists; output is `hjemConfigurations."<user>@<name>"`; relative path inputs work).
- **Q3. Rollout.** Tool (`nixos-rebuild --target-host`, deploy-rs, colmena, clan) and its metadata: target address and login, build host, privilege. That metadata belongs in the inventory (clan calls it `deploy.targetHost`), not in facts. Also decide the order (system before home on non-NixOS hosts), health check and rollback; system and home generations are independent.
- **Q4.** Is age-plugin-1p mature enough? Keep the offline key either way.
- **Q6.** Secrets for standalone and system-manager users: a small decrypt-on-login unit in the user layer, or Home Manager's agenix module there?
- **Q7.** Decided in v4: one channel plus a package overlay. Every host follows one nixpkgs branch; newer software comes as single packages through `pkgs.unstable.<name>`; overlays and nixpkgs config are one policy for NixOS systems, system-manager systems and standalone users (section 4). A nixpkgs per deployment stays out until a host needs a newer NixOS release as a whole; it would then also need the matching system-manager release.
- **Q8.** `hardware.facter.reportPath` (nixpkgs' auto-configuration from the report) is not enabled on the reference hosts, because it also changes kernel-module and DHCP settings. Decide per real host.
- **Q9.** A user delivered standalone on an otherwise NixOS-managed host needs per-user delivery metadata.
- **Q10.** Two providers for one capability (two compositors, two secret backends): today each capability has one reporting module. Choose explicitly when the second one arrives.
- **Q11. Lifecycle.** Renaming a deployment moves `secrets/rekeyed/<name>`; removing one stops producing outputs but cleans nothing on the machine. Write down the retirement order (revoke access, remove secrets and accounts, then the inventory entry). Each host owns its `system.stateVersion`; a nixpkgs upgrade must not change it.
- **Q12. Key loss and rotation.** Rekeying does not revoke what an old key could read from git history; rotating means changing the credential. Define the procedure for a lost YubiKey, a reinstalled host (new host key) and a compromised host.
- **Q13. Identity across hosts.** Partly decided in v4: the uid lives in the user's account file and is the default on every host the user is deployed to, though a host can still override it (section 10.2). Open: GID policy, whether a host should be allowed to override the uid, and login names when a home is shared or a name differs per host.
- **Q14.** Verification of hand-declared capabilities on non-NixOS hosts (a check script run on the machine).

## 16. Changes from earlier versions

### 16.1 Changes to the specification in v3

| v2 | v3 | Reason |
|---|---|---|
| `deployments.nix` entries carry `adapter` and `system` | Only `host`, `users`, `homes`; `facts.managed` selects adapters | Three places could disagree |
| `requires` as mixed shapes (`portals` a list, `udev.rules`, `setuid`) | Uniform `<kind>.<name> = { required; … }`; kinds from one table; unused kinds removed | One code path; no kind without consumer and provider |
| New capability type once two modules need it | One consumer plus one real provider, both checked | A kind nobody can fulfil is worse than a missing one |
| `reconcile { requires, provides, facts }` | `reconcile { host, requests, provides, facts }` with requests by source and a per-source verdict | Provenance; several users per host |
| `facts` example with concrete values only | Typed, `null` = unknown, read-only inside the system, `name`, `kind`, `tags`, `hostKey` added | Requirements must be able to fail; modules need a machine kind |
| "On system-manager hosts: the same" (providers) | Capabilities there are declared in hostConf | No provider uses only the portable option subset |
| Ordering text with `types.lines` + `mkOrder` | Named sections with `order` and `enable` for assembled text | Addressable contributions; stable ties |
| `files` relative path, base unspecified | Relative to `$HOME`, validated | Matches Hjem |
| Output interface `files`, `packages`, `requires` | plus `environment` | Needed by every shell and editor setup |
| Standalone: "hjem manifest + activation", decrypts secrets | Hjem standalone value; no secrets on that path | Upstream flow exists; no backend for secrets |
| Generated secrets via agenix-rekey generators | Not part of the contract yet | No consumer |
| Per-module `evalModules` tests for systemMod | A synthetic fleet exercising system modules through real hosts | System modules only mean something inside a system |
| Config checks build every toplevel in CI | Each toplevel *is* a check | No separate CI definition needed |
| R1–R8 | R1 reworded; R9–R13 added | Sections 5–7 |

### 16.2 Repairs to the first implementation

These were defects of the code, not of v2: fulfilment inside the adapter (v2 already assigned it to systemMod); `//`-merging of requirements; builders inside `deployments.nix`; hard-coded host names in checks; `readFile` of generated files (v2 already prescribed `pkgs.formats`); free-form `settings` everywhere; personal values inside framework modules; facts with defaults and two shapes; a standalone adapter without activation or warnings; `mkIf` gates presented as system-manager support; request-driven `openssh`/`greetd`/`qemu-guest` entries nobody requested. `AUDIT.md` in the repository lists each with its fix.

### 16.3 Changes in v4

| v3 | v4 | Reason |
|---|---|---|
| Every NixOS hostConf declares the login of each user it receives (`sysMod.accounts.<user>`) | `users/<user>/account.nix` says who the user is, as the default on every host the inventory deploys them to; the host decides `groups` and may add keys, a guest password, single overrides and accounts of its own. Accounts are created on NixOS hosts only. `groups`, `services` and unknown fields in an account file are rejected, naming the file | One identity per person; a new host needs no account text; the uid is shared by default; group membership is the host's grant |
| One nixpkgs; its reference and update left open (the implementation pinned a release tarball) | A branch reference (`nixos-26.05`) moved by `nix flake update`; the framework's `nixpkgs` input follows it; `sync-framework-lock` re-locks the framework's lock from the root's and compares the two path by path, as the config check does; the config check also fails when any input's `nixpkgs` stops following the root's | Updating is one command, and the framework's checks keep testing what is deployed |
| Overlay and unfree policy open; NixOS users got the system's `pkgs`, standalone users plain `legacyPackages` (Q7) | `framework.overlays` and `framework.nixpkgsConfig`, the same for NixOS systems, system-manager systems and standalone users | A package set that differs per path breaks only on some kinds of host |
| Mixed channels open (Q7) | One channel; single newer packages as `pkgs.unstable.<name>` from `nixpkgs-unstable` | A channel per host needs a nixpkgs per deployment and a system-manager release for each |
| Config checks: one per deployment | Plus `checks.<platform>.config` on the real configuration | Properties of the actual fleet (locks, identity, a headless server) are not visible in fixtures |
| Spec kept outside the repository | `docs/spec.md`, versioned with the code | It changes in the same commit as what it describes |
| Trap: a `{ }` default on a submodule-typed option bypasses the type | Removed | Not demonstrated: a direct module evaluation returned the nested default |
| Nothing refused an empty inventory or a `systems` list without a deployment's platform | The flake module refuses both before it exports any host | Either would report passing checks while running none for the hosts concerned |
| R1–R13 | R12 covers account files; R14 and R15 added | Sections 4 and 10.2 |

## 17. References

- [feel-co/hjem](https://github.com/feel-co/hjem) (`docs/inputs/standalone.md`), [feel-co/smfh](https://github.com/feel-co/smfh)
- [hercules-ci/flake-parts](https://github.com/hercules-ci/flake-parts)
- [numtide/system-manager](https://github.com/numtide/system-manager) (`nix/lib.nix`, release branches)
- [numtide/nixos-facter](https://github.com/numtide/nixos-facter)
- [ryantm/agenix](https://github.com/ryantm/agenix) · [oddlama/agenix-rekey](https://github.com/oddlama/agenix-rekey)
- [str4d/age-plugin-yubikey](https://github.com/str4d/age-plugin-yubikey) · [Enzime/age-plugin-1p](https://github.com/Enzime/age-plugin-1p)
- [RFC 189 Contracts](https://github.com/NixOS/rfcs/pull/189) and [ibizaman/selfhostblocks](https://github.com/ibizaman/selfhostblocks): request/result split, provider modules, behaviour tests
- [nix-community/srvos](https://github.com/nix-community/srvos): server baseline, one machine type per host
- [Mic92/dotfiles](https://github.com/Mic92/dotfiles): one check per machine
- [clan inventory](https://docs.clan.lol): machine fields, tags, roles on service instances
