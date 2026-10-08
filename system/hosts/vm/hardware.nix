{ ... }:
# This complete file is AI (ehm SI) slop for the vm wrapper
{
  # Persistent VM storage and EFI boot configuration.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos-root";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/nixos-esp";
    fsType = "vfat";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_net"
    "virtio_console"
  ];

  services.qemuGuest.enable = true;

  # These options are used by nixos-rebuild build-vm as well as the
  # persistent libvirt guest. They do not add host PCI devices.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 16384;
      cores = 12;
      diskSize = 102400;
      graphics = false;
    };
  };
}
