# NixOS infrastructure: config flake + framework flake

**Mod is general, Conf is specific.** `framework/` holds general modules,
the contract and the adapters. Everything else in this repository is values:
who runs where, what each host is, who each user is and what they want.

The architecture is specified in `docs/spec.md` (v4). It supersedes the v3 and
v2 drafts kept outside this repository; design changes are made in it, in the
same commit as the code. `AUDIT.md` lists what was wrong with the previous
iteration and how it was fixed. `reference.md` is the lookup for Nix, the
inputs, options and outputs of this repository, the commands used here, and the
module-system traps this repository ran into.

```
.
├── flake.nix                       # pins inputs, sets the package policy, imports the framework flake module
├── checks.nix                      # checks about this configuration (config)
├── deployments.nix                 # the inventory: which users run on which host
├── docs/spec.md                    # the architecture spec (v4)
├── overlays/unstable.nix           # pkgs.unstable.<name>: single packages from nixos-unstable
├── users/<user>/                   # userConf: profiles, preferences, sources
├── users/<user>/account.nix        # who the user is: the default login on every host
├── hosts/<host>/facts.nix          # what the host is (data)
├── hosts/<host>/facter.json        # optional hardware report, fills gaps in facts
├── hosts/<host>/default.nix        # hostConf (NixOS and system-manager hosts)
├── hosts/<host>/provides.nix       # manual hosts: capabilities supplied by hand
├── hosts/<host>/users/<user>.nix   # optional: this user on this host
└── framework/
    ├── flake-module.nix            # inventory + tree -> outputs, checks, tools
    ├── sync-framework-lock.sh      # makes framework/flake.lock pin what flake.lock pins
    ├── lib/                        # capabilities, contract, reconcile, facts, accounts, fleet, sections
    ├── home/<program>.nix          # user-layer modules (class homeMod)
    ├── system/common/              # system modules valid on NixOS and system-manager
    ├── system/nixos/               # NixOS-only system modules and capability providers
    ├── system/optional/            # providers switched on by a flake setting (secrets)
    ├── adapters/                   # NixOS, Hjem, standalone, system-manager glue
    └── checks/                     # unit checks and a synthetic fleet of 13 hosts
```

## How a host is built

`facts.managed` in `hosts/<host>/facts.nix` decides everything; the inventory
never repeats it.

| `managed` | System | Users |
|---|---|---|
| `nixos` | `nixosConfigurations.<name>` | inside the system, through Hjem |
| `system-manager` | `systemConfigs.<name>` | `hjemConfigurations."<user>@<name>"` |
| `manual` | none | `hjemConfigurations."<user>@<name>"` |

`facts.kind` (`workstation` or `server`) is what general modules gate on: the
network backend, sshd, the server baseline, and whether the host offers a
graphical session at all.

## The contract

User modules and hosts say what they need; provider modules supply it and
report what the system really has; one pure function compares the two.

```nix
requires.services.hyprland = { };            # a system service
requires.portals.gtk = { };                  # a desktop portal backend
requires.pam.hyprlock = { };                 # a PAM service
requires.secrets.token = { mode = "0400"; }; # a secret, as a runtime path
requires.facts."gpu.vendor" = { };           # a host fact that must be known
# every entry accepts `required = false`: a miss then only warns
```

- Requests keep their source, so an error reads
  `service 'hyprland' is requested by user carol but host 'nas' does not provide it`.
- One requester needing something makes it required; requesters who disagree
  on a parameter are an error.
- Providers live in `framework/system/nixos/` (`desktop.nix`, `audio.nix`,
  `pam.nix`). The desktop and audio providers offer only where
  `sysMod.desktop.enable` / `sysMod.audio.enable` is true, which defaults to
  workstations. A desktop user placed on a server is therefore refused instead
  of turning the server into a desktop.
- Facts are typed, `null` means unknown, and a requirement on an unknown or
  false fact fails.

Inspect a host:

```sh
F='path:/home/black/experimental'
nix eval --json "$F#nixosConfigurations.desktop.config.contract.facts"
nix eval --json "$F#nixosConfigurations.desktop.config.contract.provides.services"
nix eval --json "$F#nixosConfigurations.desktop.config.contract.wanted" \
  --apply 'w: builtins.mapAttrs (_: kind: builtins.mapAttrs (_: want: want.sources) kind) w'
```

## Common tasks

**Add a NixOS host.** Create `hosts/<host>/facts.nix` (`hostName`, `managed`,
`kind`, and `platform` unless a report supplies it) and
`hosts/<host>/default.nix` (hardware, `system.stateVersion`, the groups of the
users it receives), then add one line to `deployments.nix`. Outputs and its
check appear by themselves. Optionally generate the hardware report on the
machine:

```sh
sudo nix run nixpkgs#nixos-facter -- -o facter.json   # then commit it as hosts/<host>/facter.json
```

**Put a user on a host.** Three files, each deciding one thing:

- `deployments.nix` places the user: add the name to that deployment's `users`.
- `users/<user>/account.nix` says who the user is, once, as the default for
  every host: `description`, `uid`, `shell` (`bash`, `fish` or `zsh`),
  `authorizedKeys`, `hashedPassword`, `hashedPasswordFile`.
- The host's `default.nix` decides what the user may do there:
  `sysMod.accounts.<user>.groups`. It may also add `authorizedKeys`, set a
  password for a throwaway guest, override a single value (`shell`, even
  `uid`), or declare an account of its own that has no `users/` directory.

```nix
# users/black/account.nix
{
  description = "Black";
  uid = 1000;
  shell = "fish";
}

# hosts/common/vm.nix, imported by both reference hosts
sysMod.accounts.black.groups = [ "wheel" "networkmanager" "video" "input" ];
```

`groups` or `services` in an account file, or a misspelled field, fails the
build with the file and the field named. On a NixOS host, a deployed user who
has no account at all is reported by name. On system-manager and manual hosts
the login belongs to the distribution; the account file is checked there but
not applied. `hosts/<host>/users/<user>.nix` is optional and holds what
differs for the user layer on that host.

**Add a non-NixOS host.** `facts.nix` with `managed = "system-manager"` (plus a
`default.nix` using only `framework/system/common` options and declaring what
the distribution supplies, e.g. `contract.provides.services.hyprland = true;`)
or `managed = "manual"` (plus an optional `provides.nix`). Then, on that
machine:

```sh
nix run "$F#system-manager" -- switch --flake "$F#<name>" --sudo      # system-manager hosts only
nix run "$F#hjem" -- standalone switch --flake "$F" --flake-attr 'hjemConfigurations."<user>@<name>"'
```

**Add a program.** Drop `framework/home/<program>.nix`; it is discovered.
Structured config uses `settings` typed with `pkgs.formats` and
`format.generate` (never read a generated file back); text assembled from
several modules uses named `sections`. No user-, host- or checkout-specific
value belongs in it, not even as a default.

**Take a package from unstable.** Every host is built from the one nixpkgs in
`flake.nix`, the `nixos-26.05` branch. A single newer package comes from the
`nixpkgs-unstable` input as `pkgs.unstable.<name>`:

```nix
packages = [ pkgs.unstable.<name> ];                   # in a user profile
environment.systemPackages = [ pkgs.unstable.<name> ]; # in a hostConf
```

`overlays/unstable.nix` provides it and is listed in `framework.overlays` in
`flake.nix`. Overlays and nixpkgs settings such as `allowUnfree` belong there
(`framework.overlays`, `framework.nixpkgsConfig`), because from there they
reach NixOS systems, system-manager systems and standalone users alike. A whole
host or profile stays on the stable branch.

**Add a capability.** A new *name* of an existing kind needs only a provider
that enables it and sets `contract.provides.<kind>.<name>`. A new *kind* is one
entry in `framework/lib/capabilities.nix` plus its provider.

**Pass your own inputs to modules.**
`framework.moduleArgs = { flakeInputs = inputs; };` in `flake.nix` makes
`flakeInputs` an argument of hostConf and userConf. Names the framework already
uses (`inputs`, `pkgs`, `facts`, `framework`) are rejected.

## Reference deployments

| Name | What it shows |
|---|---|
| `desktop` | The libvirt guest as a workstation: facts from `facter.json`, greeter, development tools, audio requested by the host, `black` with Hyprland and Quickshell |
| `latitude` | The bare-metal Dell Latitude 5420: ZFS root on a dedicated NVMe partition, shared ESP with NixOS GRUB entries for Arch and Windows, greeter, audio and the same `black` session |
| `server` | The same guest as a server: networkd, no compositor, no compilers; `black` gets only the shell profile because the user profiles gate on `facts.kind` |

`black`'s account (uid 1000, fish) comes from `users/black/account.nix`; the
two guests import `hosts/common/vm.nix`, which adds the same groups and the
guest's password. Both keep password SSH for the throwaway guest. A real host
gets keys from the user's `authorizedKeys`, plus any its own
`sysMod.accounts.<user>.authorizedKeys` adds, and leaves password logins off;
the build refuses a key-only sshd that nobody could log into. `latitude` is a
real host: its password hash lives in `hosts/latitude/default.nix` until a
`hashedPasswordFile` secret exists, and it runs no sshd.

## Secrets

Off by default. Once a master identity exists, set in `flake.nix`:

```nix
framework.secrets = {
  directory = ./secrets;
  masterIdentities = [ ./secrets/identities/yubikey.pub ];       # identity stub
  extraEncryptionPubkeys = [ "ssh-ed25519 AAAA... 1Password" ];  # backup recipient
};
```

and give each NixOS host its SSH host public key as `hostKey` in `facts.nix`.
A module then requests `requires.secrets.<name> = { };` and reads
`config.secretPath "<name>"` (`/run/agenix/<name>`); the value never enters the
store. `nix run .#agenix -- edit secrets/<name>.age` and
`nix run .#agenix -- rekey -a` are the operator commands. A secret has exactly
one reader: the user who asked, or root when the system asked. Only NixOS hosts
have a secrets backend.

## Checks

```sh
nix flake check --no-build --all-systems --no-update-lock-file --option allow-import-from-derivation false "$F"
```

evaluates everything:

| Check | What it covers |
|---|---|
| `nixos-<name>`, `system-<name>`, `home-<user>@<name>` | one per deployment: the system toplevel, the system-manager config, a standalone user's files and packages |
| `config` | this configuration (`checks.nix`): `framework/flake.lock` agrees with `flake.lock` at every shared input path; every input takes nixpkgs from the root (an input whose `nixpkgs` leads elsewhere is reported as `different at: <input path>`); `black` has the same uid, description and shell on every host (credentials and keys are not compared); `pkgs.unstable` is newer than the base on every host and reaches the users inside NixOS; the server stays headless; the graphical layer reaches the workstation only; no contract assertion fails |
| `framework-*` | the framework's own checks against the inputs this flake locks, among them `framework-flake-inventory` (an empty inventory, or a `systems` list missing a deployment's platform, is refused), `framework-lock-graph` (the path-wise lock comparison), `framework-fleet-accounts` and `framework-fleet-packages` |

Without `--no-build` it also builds every system; `--no-update-lock-file`
makes the run fail instead of changing a lock. The synthetic fleet in
`framework/checks/fleet` runs 13 hosts (workstations and servers; NixOS,
system-manager, manual; two architectures) through the same code as the real
inventory and asserts behaviour, including the cases that must be refused. The
same command with `"$F/framework"` runs the framework's checks against its own
lock.

## Updating

Every host is built from the one nixpkgs in `flake.nix`, the `nixos-26.05`
branch: the framework's own `nixpkgs` input follows it, and there is no other
selector. If any input's `nixpkgs` stops following it, the `config` check fails
and names the input. `flake.lock` pins its revision. To update, in the
repository root:

```sh
nix flake update                 # all inputs; or one: nix flake update nixpkgs
nix run .#sync-framework-lock    # framework/flake.lock agrees with flake.lock, path by path
nix flake check --no-build --all-systems --no-update-lock-file --option allow-import-from-derivation false
```

`nix flake update` changes `flake.lock` only. `sync-framework-lock` re-locks
`framework/flake.lock` from the root lock (`nix flake lock --reference-lock-file
../flake.lock --output-lock-file flake.lock` inside `framework/`), then compares
the two locks path by path with the same code as the `config` check and exits
non-zero, listing every input path that disagrees. If the shared input paths
remain out of sync, the `config` check fails. A root-only change touches no
shared path: `nix flake update nixpkgs-unstable` moves only the packages taken
from unstable. Commit both lock files together.

After changing an input list, run `nix flake lock` and, if the framework's
inputs changed, `nix flake update framework`. Files under `framework/` must be
git-tracked to be seen.

## Activation

Nothing in this repository switches a system by itself.

```sh
sudo nixos-rebuild switch --flake 'path:/home/black/experimental#desktop'
```

`hjem standalone switch` keeps generations (`generations`, `rollback`), removes
links that are no longer configured, and moves a file that is in its way to
`.backup-<name>` next to it. Before the first switch of a NixOS host, look for
links left by an earlier Home Manager setup.
