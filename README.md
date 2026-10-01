# Modular NixOS and Home Manager configuration

This flake exposes two alternate NixOS configurations for the same simulated
VM hardware, plus independent standalone Home Manager configurations for
`black`. Desktop/laptop differences come from role policies. Home Manager
outputs are independent and do not read `osConfig`.

## Architecture boundaries

- `system/modules/` contains reusable NixOS policy and per-system tools.
- `system/hosts/vm/` owns the shared VM hardware, host settings, login session,
  and distinct desktop/laptop host names.
- `system/accounts/` owns the NixOS OS login account; it does not define Home
  Manager identity or personal preferences.
- `home/modules/` defines typed Home Manager feature options and their guarded
  `mkIf` implementations.
- `home/profiles/` composes reusable base, desktop, and development features.
- `home/users/black/` defines the separate Home Manager target (`black`,
  `/home/black`, state version `26.05`), shared personal preferences, and a
  centralized source layout.
- `home/policies/` selects the role's clock precision, Qt format string,
  bar label, and floating-toggle chord. The label, format, and chord are
  strings; precision is a string naming the Quickshell `SystemClock` member
  emitted into QML.
- Root `flake.nix` imports explicit flake-module registries. Their
  `flake.modules` entries are reusable building blocks, not runnable hosts.
- `deployments/` consumes those registry entries to construct the runnable
  NixOS and standalone Home Manager outputs.

The desktop uses `SystemClock.Seconds`, a seconds-format clock, and
`SUPER + SPACE` to toggle floating windows. The laptop uses
`SystemClock.Minutes`, a minutes-format clock, and `SUPER + V`. The old shared
`SUPER + V` floating binding is removed and generated once from the role
policy. Both alternate hosts retain the existing VM hardware, software-rendering
settings, services, packages, and NixOS state version. The pinned inputs and
`flake.lock` are unchanged.

## Outputs

- `nixosConfigurations.desktop` (`nixos-rebuild` selector `desktop`): simulated
  desktop host named `nixos-desktop`, stock kernel.
- `nixosConfigurations.laptop` (`nixos-rebuild` selector `laptop`): simulated
  laptop host named `nixos-laptop`, stock kernel.
- `homeConfigurations."black@desktop"`: standalone desktop Home Manager
  generation.
- `homeConfigurations."black@laptop"`: standalone laptop Home Manager
  generation.

NixOS outputs are host-only; each Home Manager output can be evaluated and
built independently. They are separate generations and activation commands.

## Evaluate and inspect

Run from `/home/black/nixos` as user `black`:

```sh
nix flake show --no-update-lock-file --no-write-lock-file path:/home/black/nixos
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/nixos#nixosConfigurations --apply builtins.attrNames
nix eval --json --no-update-lock-file --no-write-lock-file \
  path:/home/black/nixos#homeConfigurations --apply builtins.attrNames

nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#nixosConfigurations.desktop.config.networking.hostName'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#nixosConfigurations.laptop.config.networking.hostName'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".config.myHome.hyprland.floatingToggleChord'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".config.myHome.quickshell.clockPrecision'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".config.myHome.hyprland.floatingToggleChord'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".config.myHome.quickshell.clockPrecision'
```

Inspect the actual generated compositor loaders and Quickshell policy files:

```sh
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".config.home.file.".config/hypr/hyprland.lua".text'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".config.home.file.".config/hypr/hyprland.lua".text'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".config.home.file.".config/quickshell/black/DesktopPolicy.qml".text'
nix eval --raw --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".config.home.file.".config/quickshell/black/DesktopPolicy.qml".text'
```

## Build without activation

Build both exact NixOS toplevels and both independent Home Manager activation
packages. These commands do not activate either generation or update the lock
file:

```sh
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#nixosConfigurations.desktop.config.system.build.toplevel'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#nixosConfigurations.laptop.config.system.build.toplevel'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@desktop".activationPackage'
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/home/black/nixos#homeConfigurations."black@laptop".activationPackage'
```

## Use (activation is intentionally separate)

Only activate the matching profile on its intended host. NixOS activation
requires `sudo`; Home Manager runs as `black` without `sudo`:

```sh
sudo nixos-rebuild switch --flake 'path:/home/black/nixos#desktop' \
  --no-update-lock-file --no-write-lock-file
home-manager switch --flake 'path:/home/black/nixos#black@desktop' \
  --no-write-lock-file
```

Use `laptop` / `black@laptop` on the laptop host. NixOS and Home Manager
switches are independent and non-atomic. This architecture task performs no
activation or deployment. Generated settings can be evaluated and built here,
but visual clock/compositor behavior requires a graphical session and is not
verified by a build.
