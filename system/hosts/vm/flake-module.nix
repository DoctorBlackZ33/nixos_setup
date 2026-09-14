{ config, ... }:

let
  modules = config.flake.modules.nixos;
in {
  flake.modules.nixos.host-vm = { ... }:
    {
      imports = [
        modules.platform-x86_64-linux
        modules.system-base
        modules.system-desktop
        modules.system-development
        ./hardware.nix
      ];

      networking.hostName = "nixos-dev";
      time.timeZone = "Europe/Zurich";
      i18n.defaultLocale = "en_US.UTF-8";
      console.keyMap = "us";

      networking.networkmanager.enable = true;
      networking.firewall.enable = true;
      networking.firewall.allowedTCPPorts = [ 22 ];
      services.openssh.enable = true;
      services.greetd.enable = true;

      # The VM has no physical GPU assigned. Force the guest compositor/OpenGL
      # stack onto software rendering.
      environment.sessionVariables = {
        LIBGL_ALWAYS_SOFTWARE = "1";
        WLR_RENDERER_ALLOW_SOFTWARE = "1";
        WLR_NO_HARDWARE_CURSORS = "1";
      };

      system.stateVersion = "26.05";
    };
}
