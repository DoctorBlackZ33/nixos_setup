# NixOS infrastructure: config flake + framework flake

Implements `nixos-architecture-spec.md` (draft v2): **Mod is general, Conf is
specific**. General modules live in `framework/` (a subflake); specific values
live in this config flake. One reconcile step checks that what users need is
what hosts give, and adapters turn the result into NixOS systems or portable
home configurations.

```
.
├── flake.nix                     # config flake: inputs.framework = path:./framework
├── deployments.nix               # host -> users -> adapter
├── checks.nix                    # every deployment must evaluate
├── users/black/default.nix       # userConf (homeMod class) + sources
├── users/black/hypr/…            # user-owned Hyprland Lua fragments
├── users/black/quickshell/…      # user-owned Quickshell tree
├── hosts/common/vm.nix           # shared hostConf values for the VM hosts
├── hosts/common/vm-hardware.nix  # filesystems, bootloader, virtio, VM variant
├── hosts/common/hypr-vm.lua      # host-specific Hyprland fragment
├── hosts/<host>/facts.nix        # facts + declared provides (pure data)
├── hosts/<host>/default.nix      # hostConf (nixos class)
├── hosts/<host>/users/black.nix  # host-specific user override (homeMod class)
└── framework/
    ├── flake.nix                 # outputs: framework.lib / homeModules / systemModules / adapters
    ├── lib/contract.nix          # requires / provides / facts option types
    ├── lib/reconcile.nix         # pure reconcile function
    ├── lib/helpers.nix           # section ordering + program option template
    ├── home/<program>.nix        # homeMod modules
    ├── system/<feature>.nix      # systemMod modules (nixos class)
    ├── adapters/nixos.nix        # homeMod + systemMod -> nixosConfigurations
    ├── adapters/standalone.nix   # homeMod -> config tree / env script / package env
    └── checks/default.nix        # reconcile fixtures, contract types, module eval
```

## Layers

| Layer | Kind | Holds | Class | Lives in |
|---|---|---|---|---|
| homeMod | general | program modules: Hyprland, Quickshell, fish, git, gh, direnv, yazi, zoxide, fuzzel, mako, nvf | `homeMod` | `framework/home` |
| systemMod | general | NixOS policy: nix settings, development packages, networking, desktop hardware, locale, greeter, accounts | `nixos` | `framework/system` |
| userConf | specific | `black`'s profiles, preferences, sources | `homeMod` | `users/black` |
| hostConf | specific | hostname, hardware, kernel, locale values, greeter, accounts, facts | `nixos` | `hosts/<host>` |

Servers are built from systemMod + hostConf; a host with no users is a valid
deployment.

## Evaluation model

One lazy evaluation per host. The NixOS adapter registers the `homeMod` class
with Hjem (`hjem.extraModules`) and each user's `homeMod` is a
`submoduleWith { class = "homeMod"; specialArgs = { facts; pkgs; }; }` over the
framework's home modules plus `users/<user>/default.nix` and
`hosts/<host>/users/<user>.nix`.

Rules from the spec that the code relies on:

- **R1** `imports` never depend on `config`; everything is imported and gated
  with `mkIf` (for example `framework/system/networking.nix` gates on
  `facts.managed`).
- **R2** facts flow host -> user through `specialArgs`; `requires` flows
  user -> system through the adapter.
- **R3** homeMod modules read only `facts`, `pkgs` and their own options. The
  `homeMod` class has no access to NixOS options.
- **R4/R5** `requires` names capabilities; packages stay derivations in the
  homeMod output.
- **R6** hard requirements become `assertions`, optional ones `warnings`.
- **R7** host user overrides are homeMod files that both adapters import.
- **R8** secrets are names with a mode, never values.

## Contract

`framework/lib/contract.nix` types the three sets:

```nix
requires = {
  pam.<service>   = { };                  # { required = true; }
  portals         = [ "hyprland" "gtk" ];
  services.<name> = { };
  udev.rules      = [ ];
  setuid.<program> = { };
  secrets.<name>  = { mode = "0400"; };
  facts.<path>    = { required = true; }; # false -> warning
};
```

The Hyprland module, for example, replaces my-nixos' `osConfig` assertion with:

```nix
requires.services.hyprland = { };
requires.portals = [ "hyprland" "gtk" ];
requires.facts."gpu.vendor" = { required = true; };
```

`framework/lib/reconcile.nix` is a pure function:
`{ requires, provides, facts } -> { errors, warnings }`. It normalises partial
inputs, so fixtures and hand-written host declarations need only the keys they
care about. Checks in `framework/checks` exercise required misses (error),
optional misses (warning), and every capability type.

## Adapters

**NixOS** (`framework/adapters/nixos.nix`):

- unions `config.requires` (systemMod) with every enabled user's
  `homeMod.requires`;
- fulfils what it can: `services.hyprland` -> `programs.hyprland.enable`,
  `services.pipewire` -> `services.pipewire` + `security.rtkit`,
  `portals` -> `xdg.portal` (+ ScreenCast/Screenshot overrides for Hyprland),
  `pam.<name>` -> `security.pam.services.<name> = { }`;
- computes `provides` from its own config (PAM services, portal packages,
  service options, setuid wrappers) and takes `udev.rules` / `secrets` from the
  host declaration, since NixOS cannot introspect those;
- wires the result into `assertions` (errors) and `warnings`;
- maps `homeMod.files` onto `xdg.config.files`, `packages` onto Hjem packages
  and `environment` onto `environment.sessionVariables`.

**Standalone** (`framework/adapters/standalone.nix`): evaluates the same
homeMod modules with `lib.evalModules`, reconciles against the host's declared
`provides`, and returns a `~/.config`-shaped tree, a POSIX environment script
and a package environment. It has no activation step.

## Deployments and outputs

`deployments.nix` is the only place that knows host + user + adapter:

| Output | Contents |
|---|---|
| `nixosConfigurations.desktop` | `nixos-desktop`: VM hardware, stock kernel, systemMod set, Hjem-managed `black` |
| `nixosConfigurations.laptop` | `nixos-laptop`: same baseline, laptop role values |
| `packages.x86_64-linux."black@desktop"` | standalone `~/.config` tree |
| `packages.x86_64-linux."black@desktop-env"` | POSIX script exporting the standalone environment |
| `packages.x86_64-linux."black@desktop-packages"` | buildEnv of the standalone package list |
| `packages.x86_64-linux."black@laptop*"` | the same with laptop role values |

Role values live in `hosts/<host>/users/black.nix`: Hyprland floating-toggle
chord (`SUPER + SPACE` / `SUPER + V`), Quickshell clock precision and format
(`SystemClock.Seconds` + `yyyy-MM-dd HH:mm:ss` / `SystemClock.Minutes` +
`yyyy-MM-dd HH:mm`), bar label, and the host Hyprland fragment appended with
`lib.mkAfter`.

## Hyprland provenance

`framework/home/hyprland.nix` takes the module structure from
`/home/black/my-nixos/home/modules/hyprland.nix`: one `homeMod.<program>`
option set with `enable`, `settings` and ordered `sections` (`{ order; text; }`,
rendered with `lib.sortOn` and `types.lines`). The file content is the proven
`hl.config` / `dofile` / policy / startup layout from the previous
`experimental` implementation, now generated from those sections. The same
shape is used by every other program module, so section ordering is uniform
(`helpers.orders`).

## Checks

```sh
# framework: reconcile fixtures, contract types, home module evalModules test
nix flake check --no-build path:/home/black/experimental/framework

# config: every deployment evaluates, passes its assertions and derives a
# toplevel / standalone tree
nix flake check --no-build path:/home/black/experimental
```

Framework checks fail at evaluation time with the failing case name. The config
check forces both `system.build.toplevel.drvPath`s, all contract assertions and
the standalone package outputs.

## Evaluate, inspect, build

```sh
F='path:/home/black/experimental'
nix eval --raw  "$F#nixosConfigurations.desktop.config.networking.hostName"
nix eval --json "$F#nixosConfigurations.desktop.config.homeModRequires"
nix eval --json "$F#nixosConfigurations.desktop.config.provides"
nix eval --raw  "$F#nixosConfigurations.desktop.config.hjem.users.black.homeMod.files.\"hypr/hyprland.lua\".text"

nix build --no-link "$F#nixosConfigurations.desktop.config.system.build.toplevel"
nix build --no-link "$F#packages.x86_64-linux.\"black@desktop\""
```

When flake inputs change, run `nix flake lock` from this directory; the
`framework` input is a path flake, so its files must be git-tracked.

## Activation

Nothing was switched. Hjem runs with `clobberByDefault = false`; old Home
Manager links in `~/.config` can block its first activation. Inspect and retire
only obsolete links, then:

```sh
sudo nixos-rebuild switch --flake 'path:/home/black/experimental#desktop'
sudo nixos-rebuild switch --flake 'path:/home/black/experimental#laptop'
```

The VM display hardware belongs to the libvirt domain; `virtualisation.vmVariant`
only configures `nixos-rebuild build-vm`. greetd starts tuigreet on `tty1` with
`start-hyprland`, which the greeter derives from the required compositor
capability instead of a second compositor enum.

## Not implemented yet (spec §14 order)

- **Secrets (§11)**: the contract type, reconciliation and the NixOS
  `provides.secrets` hook exist, but agenix + agenix-rekey are not wired: no
  YubiKey identity or 1Password recipient is available here, and rekeying
  cannot be validated on this machine. A required secret currently fails the
  contract assertion instead of being decrypted.
- **system-manager adapter (§8)**: no non-NixOS host is reachable, so the
  adapter was not added rather than shipped unexercised. `facts.managed` and
  the NixOS-only `mkIf` gates are already in place for it.
- **`facter.json` (§4.2)**: facts are hand-written in `hosts/<host>/facts.nix`;
  nixos-facter is not installed on the hosts.
- **Secrets directory layout (§4)**: `secrets/` is gitignored and empty.
