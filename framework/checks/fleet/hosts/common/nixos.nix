# Smallest NixOS host that evaluates to a toplevel: a container needs no
# bootloader or filesystems.
{ ... }:
{
  boot.isContainer = true;
  # Containers borrow the host's resolv.conf by default, which networkd's
  # resolver rejects.
  networking.useHostResolvConf = false;
  system.stateVersion = "26.05";

  # An account of the host itself. Deployed users bring their own from
  # users/<user>/account.nix.
  sysMod.accounts.admin = {
    groups = [ "wheel" ];
    authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureFixtureFixtureFixtureFixtureFixtureFix admin" ];
  };
}
