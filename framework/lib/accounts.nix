# What a login account is. Who a user is (name shown, uid, shell, keys) is
# the user's own data in `users/<user>/account.nix` and is the same on every
# host. Which groups they are in is each host's decision.
{ lib, typed }:
let
  inherit (lib) mkOption types;

  shells = [ "bash" "fish" "zsh" ];

  identity = {
    description = mkOption {
      type = types.str;
      default = "";
      description = "Full name or purpose of the account.";
    };
    uid = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = "Fixed user id, so files keep their owner from host to host.";
    };
    shell = mkOption {
      type = types.enum shells;
      default = "bash";
      description = "Login shell. The matching `programs.<shell>` is enabled for it.";
    };
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "SSH public keys allowed to log in.";
    };
    hashedPassword = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Password hash. It is world-readable in the Nix store, so use it for
        throwaway machines only; real hosts use `hashedPasswordFile`.
      '';
    };
    hashedPasswordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Runtime path of a file holding the password hash, for example a secret.";
    };
  };

  membership = {
    groups = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Supplementary groups on this host.";
    };
  };
in
{
  inherit shells;

  # Account files use shell identities, not nixpkgs' package names.
  shellIdentity = shell:
    let name = lib.getName shell;
    in if name == "bash-interactive" then "bash" else name;

  # Options of `sysMod.accounts.<name>` on a host.
  hostOptions = identity // membership;

  # What is wrong with `user`'s account file, one message per field, each
  # naming the file. The fleet builder refuses the deployment with them, so a
  # mistake shows wherever the user is listed, whatever kind of host it is.
  problems = user: file: data:
    map
      (field:
        if field == "groups" then
          "${file} sets `groups`, but group membership is decided per host (sysMod.accounts.${user}.groups)"
        else
          "${file}: `${field}` is not an account field (fields: ${lib.concatStringsSep ", " (lib.attrNames identity)})")
      (lib.subtractLists (lib.attrNames identity) (lib.attrNames data));

  # A user's account file, typed: what `problems` does not cover, a value of
  # the wrong type, fails here with the file named.
  evalUser = file: data: typed.evalFile (types.submodule { options = identity; }) file data;

  # The same data as host definitions: single values yield to a host's own,
  # lists add up.
  asHostDefinitions = data:
    lib.mapAttrs (_: value: if lib.isList value then value else lib.mkDefault value) data;
}
