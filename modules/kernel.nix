{ kernelProfile, nix-cachyos-kernel, pkgs, ... }:

{
  # Keep the generic NixOS kernel as the first bootable generation. The
  # Cachy profile is selected explicitly with nixos-rebuild --flake
  # .#nixos-dev-cachy and leaves the stock generations in systemd-boot.
  boot.kernelPackages =
    if kernelProfile == "stock" then
      pkgs.linuxPackages
    else if kernelProfile == "cachy" then
      pkgs.cachyosKernels."linuxPackages-cachyos-latest-lto-x86_64-v4"
    else
      throw "Unknown kernelProfile: ${kernelProfile}";

  nixpkgs.overlays =
    if kernelProfile == "cachy" then
      [ nix-cachyos-kernel.overlays.pinned ]
    else
      [ ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_net"
    "virtio_console"
  ];
}
