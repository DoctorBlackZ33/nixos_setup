{ ... }:
{
  imports = [ ../common/nixos.nix ];

  sysMod.greeter.enable = true;
  sysMod.development.enable = true;

  # This host's decisions about alice's account.
  sysMod.accounts.alice = {
    groups = [ "wheel" ];
    authorizedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureFixtureFixtureFixtureFixtureFixtureFix alice-on-ws-2" ];
  };
}
