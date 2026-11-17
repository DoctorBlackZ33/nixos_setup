# Dell Latitude 5420 hardware. One NVMe disk: NixOS lives on ZFS in
# nvme0n1p11 and shares the existing 2G ESP (nvme0n1p1) with Arch and
# Windows. Nothing here formats or mounts the other partitions.
{ ... }:
{
  fileSystems."/" = {
    device = "zroot/root/nixos";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/3DE4-5FED";
    fsType = "vfat";
  };

  # The ESP is shared with Arch and Windows. Arch's GRUB owns /boot/grub and
  # rewrites it on every package transaction (grub-btrfs), so NixOS must not
  # keep its menu there: systemd-boot uses /boot/loader and /boot/EFI/systemd,
  # which GRUB never writes. Arch's GRUB gains a chainload entry for it.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.timeout = 5;

  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.efi.canTouchEfiVariables = true;

  boot.supportedFilesystems = [ "zfs" ];
  boot.initrd.supportedFilesystems = [ "zfs" ];
  # Import the root pool by name without bypassing ZFS' import safeguards.
  boot.zfs.forceImportRoot = false;
  services.zfs.autoScrub.enable = true;
  networking.hostId = "535c8c9d";

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.kernelModules = [ "kvm-intel" "coretemp" ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
}
