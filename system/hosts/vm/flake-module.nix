{ config, ... }:

let
  modules = config.flake.modules.nixos;
in {
  flake.modules.nixos = {
    host-vm-common = { pkgs, ... }: {
      imports = [
        modules.platform-x86_64-linux
        modules.system-base
        modules.system-desktop
        modules.system-development
        ./hardware.nix
      ];

      time.timeZone = "Europe/Zurich";
      i18n.defaultLocale = "en_US.UTF-8";
      console.keyMap = "us";

      networking.networkmanager.enable = true;
      networking.firewall.enable = true;
      networking.firewall.allowedTCPPorts = [ 22 ];
      services.openssh.enable = true;
      services.greetd = {
        enable = true;
        settings.default_session = {
          user = "black";
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
        };
      };

      # The simulated hosts have no physical GPU. Force guest compositor and
      # OpenGL work onto software rendering, like the existing VM host.
      environment.sessionVariables = {
        LIBGL_ALWAYS_SOFTWARE = "1";
        WLR_RENDERER_ALLOW_SOFTWARE = "1";
        WLR_NO_HARDWARE_CURSORS = "1";
      };

      system.stateVersion = "26.05";
    };

    host-desktop = {
      imports = [ modules.host-vm-common ];
      networking.hostName = "nixos-desktop";
    };

    host-laptop = {
      imports = [ modules.host-vm-common ];
      networking.hostName = "nixos-laptop";
    };
  };
}
