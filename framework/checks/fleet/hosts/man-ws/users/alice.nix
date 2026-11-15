# Host-specific user override on a host without a NixOS evaluation (R7).
{ ... }:
{
  files.".config/demo/host".text = "man-ws";
}
