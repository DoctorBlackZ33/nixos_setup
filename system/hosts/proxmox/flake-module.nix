{ config, ... }:

let
  modules = config.flake.modules.nixos;
in {
  flake.modules.nixos = {
    host-proxmox-common = {
      imports = [
        modules.system-base
        modules.system-development
      ];

      boot.loader.grub = {
        enable = true;
        efiSupport = false;
      };

      time.timeZone = "Europe/Zurich";
      i18n.defaultLocale = "en_US.UTF-8";
      console.keyMap = "us";

      networking.networkmanager.enable = true;
      networking.firewall.enable = true;
      services.qemuGuest.enable = true;
      services.openssh = {
        enable = true;
        openFirewall = true;
        settings = {
          PasswordAuthentication = true;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      users.mutableUsers = true;
      users.users.root.hashedPassword = "!";
      system.stateVersion = "26.05";
    };

    host-k3-vm-1 = {
      imports = [
        modules.host-proxmox-common
        ./k3-vm-1/hardware.nix
      ];
      networking.hostName = "k3-vm-1";
      boot.loader.grub.device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
    };

    host-k3-vm-2 = {
      imports = [
        modules.host-proxmox-common
        ./k3-vm-2/hardware.nix
      ];
      networking.hostName = "k3-vm-2";
      boot.loader.grub.device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
    };
  };
}
