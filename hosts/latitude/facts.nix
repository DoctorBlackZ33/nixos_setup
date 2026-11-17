# The Latitude 5420: bare metal, Intel Iris Xe, one 1920x1080 panel.
{
  hostName = "latitude";
  platform = "x86_64-linux";
  managed = "nixos";
  kind = "workstation";
  location = "home";

  gpu.vendor = "intel";
  displays = [
    {
      width = 1920;
      height = 1080;
      refresh = 60;
    }
  ];
}
