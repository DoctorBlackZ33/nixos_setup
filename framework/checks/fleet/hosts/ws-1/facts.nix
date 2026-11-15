{
  hostName = "ws-1";
  platform = "x86_64-linux";
  managed = "nixos";
  kind = "workstation";
  gpu.vendor = "amd";
  displays = [ { width = 2560; height = 1440; refresh = 144; } ];
}
