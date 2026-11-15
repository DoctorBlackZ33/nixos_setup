# Reference server. It has no hardware report, so the facts a report would
# supply are written by hand.
{
  hostName = "nixos-server";
  platform = "x86_64-linux";
  managed = "nixos";
  kind = "server";
  location = "home";
  virtualisation = "kvm";
}
