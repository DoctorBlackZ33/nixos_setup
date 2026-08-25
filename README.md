# NixOS system

This repository is the source of truth for the first NixOS development VM.

The VM is intentionally independent from `/home/black/end4_custom`. It starts
with a small software-rendered Hyprland desktop and a stock NixOS kernel.
The Cachy-derived kernel configuration is a second profile and must keep the
stock kernel available as a fallback.

## Build targets

- `nixos-dev`: stock NixOS kernel, baseline VM
- `nixos-dev-cachy`: CachyOS-derived LTO/x86-64-v4 kernel profile

The Cachy profile is intentionally host-specific: it assumes the VM exposes
the host CPU and that the host supports x86-64-v4. Keep `nixos-dev` as the
fallback on machines with a different CPU feature set.

## Rebuild and rollback

From `/etc/nixos` inside the VM:

```sh
sudo nixos-rebuild switch --flake .#nixos-dev
sudo nixos-rebuild switch --flake .#nixos-dev-cachy
sudo nixos-rebuild switch --rollback
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Every rebuild creates a bootable generation. If a kernel or system change
does not boot, select an older generation from systemd-boot or use the stock
kernel target above.

## Rice workflow

Rice files under `rice/` are immutable Home Manager sources by default. Set
`rice.devMode = true` in the VM host module only when deliberately testing
live files from this repository. `rice.sourceRoot` can point at another Git
worktree, allowing separate rice experiments or VMs to use different projects
while sharing the same system modules. The dev mode is limited to rice files;
the system, packages, services, and kernel remain declarative.

The committed VM account uses the bootstrap password `nixos`; change the
`hashedPassword` in `modules/base.nix` before exposing the VM beyond the local
libvirt network.

## Neovim

The committed LazyVim configuration lives under `home/neovim/`. The Home
Manager Neovim module deploys its Lua files and lockfile, while the wrapper
provides the editor, language servers, formatters, linters, and other CLI
tools from Nix. The runtime Lazy.nvim data directory remains user-writable;
the committed `lazy-lock.json` is seeded there on each Home Manager
activation.

The port keeps the editor core, UI, Markdown, Nix, JSON, TOML, Git, Yazi, and
dotfile support. Its Nix language setup uses `nixd`, Alejandra, and Statix.
Host-only task, remote-SSHFS, Codex, and large language-specific IDE layers
are intentionally deferred until their VM dependencies are designed.

## VM storage

The persistent libvirt disk is intentionally outside this Git repository:

`/mnt/SSD/VM_Storage/nixos-dev.qcow2`

The existing `win11.qcow2` must not be reused or modified.
