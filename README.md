# Composable Nix deployment

This repository uses flake-parts registries for reusable NixOS capabilities,
Home Manager modules, profiles, and user identities. Deployments are the only
composition boundary that binds a host, account, source layout, and output.

## Outputs

- `nixos-dev`: VM host with the stock kernel.
- `nixos-dev-cachy`: VM host with the pinned CachyOS kernel.
- `homeConfigurations.black`: generic standalone black home.
- `homeConfigurations."black@vm"`: production VM home with store-backed sources.
- `homeConfigurations."black@vm-live"`: VM hot-reload home with `/etc/nixos`
  out-of-store sources.

NixOS outputs are host-only; Home Manager is standalone and evaluated independently.
Non-NixOS support means Linux with Nix and an existing
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

From the VM checkout, inspect the output graph:

```sh
nix flake show path:/etc/nixos
nix flake check --no-build --no-update-lock-file path:/etc/nixos --print-build-logs
```

Build systems without switching:

```sh
nixos-rebuild build --flake path:/etc/nixos#nixos-dev
nixos-rebuild build --flake path:/etc/nixos#nixos-dev-cachy
```

Build or activate standalone homes as user `black`:

```sh
nix build path:/etc/nixos#homeConfigurations.black.activationPackage
nix build path:/etc/nixos#homeConfigurations."black@vm".activationPackage
nix build path:/etc/nixos#homeConfigurations."black@vm-live".activationPackage
home-manager switch --flake path:/etc/nixos#black@vm
home-manager switch --flake path:/etc/nixos#black@vm-live
```
