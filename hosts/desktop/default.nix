# Reference workstation: the libvirt guest with a graphical session.
{ pkgs, ... }:
{
  imports = [ ../common/vm.nix ];

  sysMod.greeter = {
    enable = true;
    arguments = [ "--time" ];
  };

  sysMod.development.enable = true;

  # The workstation itself wants sound, whoever logs in.
  contract.requires.services.pipewire = { };

  fonts.packages = [ pkgs.noto-fonts ];

  # The guest has no GPU passthrough: render the compositor in software.
  environment.sessionVariables = {
    LIBGL_ALWAYS_SOFTWARE = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
