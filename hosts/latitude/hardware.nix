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

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = false;
    zfsSupport = true;

    # /boot is shared, so keep the menu and its kernels bounded.
    configurationLimit = 5;

    # The other operating systems that already use this ESP. Explicit entries:
    # os-prober would have to guess the btrfs subvolume and the Windows loader.
    extraEntries = ''
      menuentry "Arch Linux" --class arch --class gnu-linux {
        insmod part_gpt
        insmod fat
        search --no-floppy --fs-uuid --set=root 3DE4-5FED
        linux /vmlinuz-linux root=UUID=8cb1c893-19ba-4faa-ba4c-0c0b145bc4dc rw rootflags=subvol=@ rootfstype=btrfs zswap.enabled=0 quiet loglevel=3 udev.log-priority=3 i915.modeset=1 splash fbcon=nodefer
        initrd /intel-ucode.img /initramfs-linux.img
      }

      menuentry "Windows Boot Manager" --class windows {
        insmod part_gpt
        insmod fat
        search --no-floppy --fs-uuid --set=root 3DE4-5FED
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
  };

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
