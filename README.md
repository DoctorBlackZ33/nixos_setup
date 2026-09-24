# Composable Nix deployment

This repository uses flake-parts registries for reusable NixOS capabilities,
Home Manager modules, profiles, and user identities. Deployments are the only
composition boundary that binds a host, account, source layout, and output.

## Outputs

- `nixos-dev`: VM host with the stock kernel. This is the host-only NixOS output.
- `nixos-dev-cachy`: VM host with the pinned CachyOS kernel.
- `homeConfigurations.black`: generic standalone black home.
- `homeConfigurations."black@vm"`: standalone Home Manager home for the production VM, with store-backed sources.
- `homeConfigurations."black@vm-live"`: VM hot-reload home with `/etc/nixos`
  out-of-store sources.

NixOS outputs are host-only; Home Manager outputs are standalone and evaluated
independently. Non-NixOS support means Linux with Nix and an existing
black account.

## Source layout

- `system/modules/` contains reusable NixOS policy and developer outputs.
- `system/hosts/vm/` contains the VM host registry entry and hardware facts.
- `home/modules/` and `home/profiles/` contain reusable Home Manager entries.
- `home/users/black/` contains the black identity and user-owned sources.
- `deployments/` contains concrete system and standalone home compositions.
- Shared QML and Hyprland sources live under `home/config/`; VM-specific
  components live under `deployments/vm/black/config/`.

## Commands

Run these commands on the target VM as user `black`. The `nixos-dev` output is
the host-only NixOS configuration; `black@vm` is a standalone Home Manager
configuration. They are separate outputs and activate independently.

Inspect the output graph without changing the lock file:

```sh
nix flake show --no-update-lock-file --no-write-lock-file path:/etc/nixos
nix flake check --no-build --no-update-lock-file --no-write-lock-file path:/etc/nixos --print-build-logs
```

Build both derivations without activating either one:

```sh
nixos-rebuild build --flake 'path:/etc/nixos#nixos-dev' \
  --no-update-lock-file --no-write-lock-file
nix build --no-link --no-update-lock-file --no-write-lock-file \
  'path:/etc/nixos#homeConfigurations."black@vm".activationPackage'
```

`--flake` selects the flake and output. `--no-update-lock-file` forbids lock
file updates, and `--no-write-lock-file` prevents writing a generated lock
file. `--no-link` avoids creating a result symlink for the Home Manager build.
The `nixos-rebuild build` and `nix build` commands only build; neither activates
its result.

Switch NixOS only (sudo is required for this activation):

```sh
sudo nixos-rebuild switch --flake 'path:/etc/nixos#nixos-dev' \
  --no-update-lock-file --no-write-lock-file
```

Switch standalone Home Manager only (never use sudo):

```sh
home-manager switch --flake 'path:/etc/nixos#black@vm' \
  --no-write-lock-file
```

Run both switches sequentially:

```sh
sudo nixos-rebuild switch --flake 'path:/etc/nixos#nixos-dev' \
  --no-update-lock-file --no-write-lock-file &&
home-manager switch --flake 'path:/etc/nixos#black@vm' \
  --no-write-lock-file
```

There is no atomic combined activation: these are two separate commands, and
each activation takes effect independently. With `&&`, Home Manager is not
attempted if the NixOS switch fails. If NixOS succeeds but Home Manager fails,
the NixOS switch remains active while Home Manager stays at its previous
generation. Run `home-manager` as `black` without sudo; use sudo only on
`nixos-rebuild`.
