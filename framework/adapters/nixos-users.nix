# The user layer of a NixOS host: every enabled Hjem user becomes a named
# requester of the contract. Imported only for deployments that have users, so
# a server without users carries no Hjem at all.
{ config, lib, ... }:
let
  users = lib.filterAttrs (_: user: user.enable) config.hjem.users;
  account = name: config.users.users.${name};
in
{
  imports = [ ./hjem-register.nix ];

  contract.requests =
    lib.mapAttrs' (name: user: lib.nameValuePair "user ${name}" user.homeMod.requires) users;

  # The inventory places a user on a host; the login account stays a host
  # decision. Say so, instead of leaving it to a NixOS error about user types.
  assertions = lib.mapAttrsToList
    (name: _: {
      assertion = (account name).isNormalUser || (account name).isSystemUser;
      message = ''
        host '${config.contract.facts.name}': user '${name}' is deployed here but has no
        account. Add `sysMod.accounts.${name}` to the host configuration.
      '';
    })
    users;
}
