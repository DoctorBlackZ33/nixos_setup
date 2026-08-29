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

## Module generator and Nix snippets

The enabled Home Manager defaults install `new-module`, which creates a Home
module from the repository template without changing imports:

```sh
new-module home quickshell
```

The command accepts exactly `home` and a name matching
`^[a-z][a-z0-9_-]*$`. It refuses existing targets and reports `system` as
reserved/not implemented. After a successful run, add the printed
`./quickshell.nix` path manually to the imports in
`home/modules/defaults.nix`.

In a Nix buffer, type `mkopt` and expand the LuaSnip snippet to insert a
`lib.mkOption` block. Tab through the option identifier, type, default value,
and description. LuaSnip supplies snippet expansion while blink.cmp remains
the completion engine.

## Rebuild and rollback

From `/etc/nixos` inside the VM:

```sh
sudo nixos-rebuild switch --flake .#nixos-dev
sudo nixos-rebuild switch --flake .#nixos-dev-cachy
sudo nixos-rebuild switch --rollback
nixos-rebuild build-vm --flake .#nixos-dev
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system
```

Every rebuild creates a bootable generation. If a kernel or system change
does not boot, select an older generation from systemd-boot or use the stock
kernel target above.

The `build-vm` target uses the VM-only virtio, guest-agent, software-rendering,
and virtual-machine sizing settings from `hosts/vm/default.nix`.

## Rice workflow

Rice files under `rice/` are immutable Home Manager sources by default. Set
`rice.devMode = true` in the VM host module only when deliberately testing
live files from this repository. `rice.sourceRoot` can point at another Git
worktree, allowing separate rice experiments or VMs to use different projects
while sharing the same system modules. The dev mode is limited to rice files;
the system, packages, services, and kernel remain declarative.

The committed VM account uses the bootstrap password `nixos`; change the
`hashedPassword` in `system/modules/base.nix` before exposing the VM
beyond the local libvirt network.

## VM storage

The persistent libvirt disk is intentionally outside this Git repository:

`/mnt/SSD/VM_Storage/nixos-dev.qcow2`

The existing `win11.qcow2` must not be reused or modified.
