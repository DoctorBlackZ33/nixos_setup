{
  hostName = "nixos-dev-vm";
  platform = "x86_64-linux";
  managed = "nixos";
  kind = "workstation";
  location = "home";

  displays = [
    {
      width = 1920;
      height = 1080;
      refresh = 60;
    }
  ];
}
