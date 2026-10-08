{ config, ... }:

let
  modules = config.flake.modules.nixos;
in 
{
  flake.modules.nixos = {
    imports = [
      modules.sysMod-nix-settings
      modules.sysMod-desktop
      modules.sysMod-development
      modules.sysMod-networking
      modules.sysMod-tty
    ];
    # The following is slop for the vm wrapper. 
    # The simulated hosts have no physical GPU. Force guest compositor and
    # OpenGL work onto software rendering, like the existing VM host.
    environment.sessionVariables = {
      LIBGL_ALWAYS_SOFTWARE = "1";
      WLR_RENDERER_ALLOW_SOFTWARE = "1";
      WLR_NO_HARDWARE_CURSORS = "1";
    };

    networking.hostName = "nixos-desktop";
    system.stateVersion = "26.05";
  };
  
}
