# NixOS infrastructure: config flake + framework flake

**Mod is general, Conf is specific.** `framework/` holds general modules,
the contract and the adapters. Everything else in this repository is values:
who runs where, what each host is, what each user wants.

The architecture is specified in `nixos-architecture-spec-v3.md` (kept outside
this repository, next to the v2 spec). `AUDIT.md` lists what was wrong with the
previous iteration and how it was fixed. `reference.md` is the lookup for Nix,
the commands used here, and the module-system traps this repository ran into.

```
.
├── flake.nix                       # pins inputs, imports the framework flake module
├── deployments.nix                 # the inventory: which users run on which host
├── users/<user>/                   # userConf: profiles, preferences, sources
├── hosts/<host>/facts.nix          # what the host is (data)
├── hosts/<host>/facter.json        # optional hardware report, fills gaps in facts
├── hosts/<host>/default.nix        # hostConf (NixOS and system-manager hosts)
├── hosts/<host>/provides.nix       # manual hosts: capabilities supplied by hand
├── hosts/<host>/users/<user>.nix   # optional: this user on this host
└── framework/
    ├── flake-module.nix            # inventory + tree -> outputs, checks, tools
    ├── lib/                        # capabilities, contract, reconcile, facts, fleet, sections
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
`hosts/<host>/default.nix` (hardware, `system.stateVersion`, accounts), then add
one line to `deployments.nix`. Outputs and its check appear by themselves.
Optionally generate the hardware report on the machine:

```sh
sudo nix run nixpkgs#nixos-facter -- -o facter.json   # then commit it as hosts/<host>/facter.json
```

**Put a user on a host.** Add the name to `users` in `deployments.nix`. On a
NixOS host also declare the login in its hostConf (`sysMod.accounts.<user>`);
the build tells you if you forget. `hosts/<host>/users/<user>.nix` is optional
and holds what differs on that host.

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
| `server` | The same guest as a server: networkd, no compositor, no compilers; `black` gets only the shell profile because the user profiles gate on `facts.kind` |

Both keep password SSH for the throwaway guest. A real host lists
`sysMod.accounts.<user>.authorizedKeys` and leaves password logins off; the
build refuses a key-only sshd that nobody could log into.

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
nix flake check --no-build --all-systems --option allow-import-from-derivation false "$F"
```

evaluates everything: one check per deployment (`nixos-<name>`,
`system-<name>`, `home-<user>@<name>`) and the framework's own checks against
the inputs this flake locks (`framework-*`). Without `--no-build` it also
builds every system. The synthetic fleet in `framework/checks/fleet` runs 13
hosts (workstations and servers; NixOS, system-manager, manual; two
architectures) through the same code as the real inventory and asserts
behaviour, including the cases that must be refused.

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
