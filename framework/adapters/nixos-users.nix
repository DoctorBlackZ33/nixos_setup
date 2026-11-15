# The user layer of a NixOS host: every enabled Hjem user becomes a named
# requester of the contract. Imported only for deployments that have users, so
# a server without users carries no Hjem at all.
{ deployedUsers }:
{ config, lib, ... }:
let
  users = lib.filterAttrs (_: user: user.enable) config.hjem.users;
  account = name: config.users.users.${name} or { isNormalUser = false; isSystemUser = false; };
in
{
  imports = [ ./hjem-register.nix ];

  contract.requests =
    lib.mapAttrs' (name: user: lib.nameValuePair "user ${name}" user.homeMod.requires) users;

  # The inventory places a user on a host and the fleet builder brings the
  # account from users/<user>/account.nix. Without that file, say so instead
  # of leaving it to a NixOS error about user types.
  assertions = map
    (name: {
      assertion = (account name).isNormalUser || (account name).isSystemUser;
      message = ''
        host '${config.contract.facts.name}': user '${name}' is deployed here but has no
        account. Add users/${name}/account.nix.
      '';
    })
    deployedUsers;
}
