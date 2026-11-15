# Smallest NixOS host that evaluates to a toplevel: a container needs no
# bootloader or filesystems.
{ lib, ... }:
let
  key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureFixtureFixtureFixtureFixtureFixtureFix fixture";
in
{
  boot.isContainer = true;
  # Containers borrow the host's resolv.conf by default, which networkd's
  # resolver rejects.
  networking.useHostResolvConf = false;
  system.stateVersion = "26.05";

  # Every fixture user except erin, who is deployed without an account on
  # purpose.
  sysMod.accounts = lib.genAttrs [ "alice" "bob" "carol" "dave" "dana" "frank" ] (_: {
    groups = [ "wheel" ];
    shell = "fish";
    authorizedKeys = [ key ];
  });
}
