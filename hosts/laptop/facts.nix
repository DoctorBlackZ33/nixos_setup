{
  facts = {
    hostName = "nixos-laptop";
    platform = "x86_64-linux";
    location = "home";
    managed = "nixos";
    gpu = {
      vendor = "virtual";
      vulkan = false;
    };
    displays = [ ];
  };
  provides = {
    portals = [ "hyprland" "gtk" ];
    services = {
      hyprland = true;
      pipewire = true;
    };
  };
}
