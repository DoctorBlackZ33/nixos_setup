# Modular NixOS and programmod configuration

This flake exposes two alternate NixOS configurations for the same simulated
VM hardware. Each config manages `black` through Hjem and evaluates the same
programmod source, preference, and profile modules. The desktop and laptop
roles differ only through their policy modules. Standalone programmod configs
are also available and do not depend on Hjem or `osConfig`.

## Architecture boundaries

- `system/modules/` contains reusable NixOS policy and per-system tools.
- `system/hosts/vm/` owns shared VM hardware, host settings, login session,
  and distinct desktop/laptop host names.
- `system/accounts/` owns the NixOS OS login account.
- `home/programmod/` contains the independent programmod evaluator, core,
  program modules, and NixOS/Hjem adapters. Program modules generate files,
  packages, and session environment without reading NixOS or Hjem options.
- `home/profiles/` composes base, desktop, and development features and
  package-only tools.
- `home/users/black/` composes personal preferences and profiles and
  centralizes Hyprland and Quickshell source paths.
- `home/policies/` supplies role-specific `desktopPolicy` values: floating
  toggle chord, Quickshell clock precision, date-time format, and bar label.
- Root `flake.nix` imports explicit flake-module registries. Their
  `flake.modules` entries are reusable building blocks, not runnable hosts.
- `deployments/` constructs the NixOS/Hjem hosts and standalone programmod
  configurations from those registries.

The Hjem input follows `nixpkgs`; both NixOS hosts import Hjem and the
programmod NixOS adapter. Hjem owns the `/home/black` target on each host.
The Home Manager module integration and standalone Home Manager outputs have
been removed; the base profile retains the Home Manager CLI as the plain
`pkgs.home-manager` package.

The desktop uses `SystemClock.Seconds`, a seconds-format clock, and
`SUPER + SPACE` to toggle floating windows. The laptop uses
`SystemClock.Minutes`, a minutes-format clock, and `SUPER + V`. The floating
binding is generated once from `desktopPolicy`. Both hosts retain the existing
VM hardware, software-rendering settings, services, packages, and NixOS state
version. `nvf` uses its independent `lib.nvim.neovimConfiguration` API and
retains the existing editor settings, plugins, keymaps, and Lua hooks.

## Outputs

- `nixosConfigurations.desktop` (`nixos-rebuild` selector `desktop`): simulated
  desktop host named `nixos-desktop`, stock kernel, and Hjem-managed user.
- `nixosConfigurations.laptop` (`nixos-rebuild` selector `laptop`): simulated
  laptop host named `nixos-laptop`, stock kernel, and Hjem-managed user.
- `programmodConfigurations."black@desktop"`: standalone programmod config
  containing `files`, `packages`, `environment`, and `build.*` outputs.
- `programmodConfigurations."black@laptop"`: the same standalone config with
  the laptop policy.
- `packages.x86_64-linux.programmod-configDir-black-desktop` and
  `programmod-configDir-black-laptop`: buildable `~/.config` trees.
- `packages.x86_64-linux.programmod-packages-black-desktop` and
  `programmod-packages-black-laptop`: buildable package environments from each
  standalone config's `packages`.

Standalone configurations use the same base, development, and desktop
profiles, user preferences, source catalog, and role policies as Hjem. They
produce no activation package. The Fish program module renders `environment`
as the shared Fish-native `programmod-environment` section for standalone and
Hjem delivery. The config result also exposes `build.files`, `build.configDir`,
and a POSIX `build.loadEnv` script for standalone shells without Fish.

## Evaluate and inspect

Run from `/home/black/experimental` as user `black`. When flake inputs change,
run `nix flake lock` from that directory to update the lock:

```sh
nix flake show --no-update-lock-file --no-write-lock-file path:/home/black/experimental
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/experimental#nixosConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/experimental#programmodConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/experimental#packages.x86_64-linux --apply builtins.attrNames

nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#nixosConfigurations.desktop.config.networking.hostName'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#nixosConfigurations.laptop.config.networking.hostName'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#programmodConfigurations."black@desktop".desktopPolicy.hyprland.floatingToggleChord'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#programmodConfigurations."black@desktop".desktopPolicy.quickshell.clockPrecision'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#programmodConfigurations."black@laptop".desktopPolicy.hyprland.floatingToggleChord'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#programmodConfigurations."black@laptop".desktopPolicy.quickshell.clockPrecision'
```

The corresponding NixOS/Hjem values are under
`nixosConfigurations.<host>.config.hjem.users.black.homeMod`. Inspect the
standalone generated Hyprland and Quickshell file text with:

```sh
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#programmodConfigurations."black@desktop".files."hypr/hyprland.lua".text'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#programmodConfigurations."black@laptop".files."hypr/hyprland.lua".text'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#programmodConfigurations."black@desktop".files."quickshell/black/DesktopPolicy.qml".text'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#programmodConfigurations."black@laptop".files."quickshell/black/DesktopPolicy.qml".text'
```

TOML settings use `pkgs.formats.toml` with `builtins.readFile`, so evaluating
those generated settings uses import-from-derivation (IFD) and builds a small
TOML generator during evaluation.

## Programmod self-check

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

The expression returns `{ ok = true; }` only when its DAG/section ordering and
merge, file/environment validation, disabled/null-package behavior, class
check, Hjem delivery, and NixOS Hyprland-hook assertions pass.

## Build without activation

These commands build both NixOS toplevels and standalone config/package
outputs; they do not activate either generation:

```sh
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#nixosConfigurations.desktop.config.system.build.toplevel'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#nixosConfigurations.laptop.config.system.build.toplevel'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#packages.x86_64-linux.programmod-configDir-black-desktop'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#packages.x86_64-linux.programmod-configDir-black-laptop'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#packages.x86_64-linux.programmod-packages-black-desktop'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/experimental#packages.x86_64-linux.programmod-packages-black-laptop'
```

No switch or activation was run as part of this migration. The Hjem-managed
configuration is part of each NixOS host; standalone programmod outputs are
config trees and package environments, not activation generations.

## First activation after cutover

Before the first switch, inspect the existing Home Manager generation and
`~/.config` links. Hjem has `clobberByDefault = false`, so old Home
Manager-managed links can block Hjem's first file activation. Retire only
obsolete Home Manager-owned links/generation as appropriate for how the old
configuration was deployed; use Home Manager's uninstall workflow only if the
old setup was a standalone Home Manager deployment. Preserve unrelated user
files. Do not set `clobberFiles = true` as a blanket workaround.

After reviewing those existing files, the operator can activate either host:

```sh
sudo nixos-rebuild switch --flake 'path:/home/black/experimental#desktop'
sudo nixos-rebuild switch --flake 'path:/home/black/experimental#laptop'
```

These are documented operator commands; neither was run by the assistant.

## VM display and startup lifecycle

The VM's persistent display hardware belongs to its libvirt domain, not this
flake. The `virtualisation.vmVariant` settings in
`system/hosts/vm/hardware.nix` configure the `nixos-rebuild build-vm` output;
they do not add or change PCI devices in an existing libvirt domain. The
libvirt domain must attach a video device (virtio GPU) and expose a host-only
graphical console. `hardware.graphics.enable` and software-rendering
environment variables configure the guest's software stack, but cannot create
missing display hardware.

On boot, system-level greetd starts tuigreet on `tty1` with `start-hyprland` as
the post-authentication command. Hyprland starts only after the user
authenticates; Quickshell is not expected at the greeter. The programmod
configuration installs the Hyprland Lua loader and Quickshell source tree, and
starts `quickshell --config black` when Hyprland starts. Hjem manages these
files as part of the host's user configuration.
