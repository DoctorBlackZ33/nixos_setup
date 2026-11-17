# Checks about this configuration. How the framework behaves is covered by its
# own checks, which run here as `framework-*`; these look at the real
# inventory.
{ config, inputs, lib, ... }:
let
  hosts = lib.mapAttrs (_: host: host.config) config.flake.nixosConfigurations;
  packages = lib.mapAttrs (_: host: host.pkgs) config.flake.nixosConfigurations;

  # --- the two lock files -------------------------------------------------
  rootLock = lib.importJSON ./flake.lock;
  frameworkLock = lib.importJSON ./framework/flake.lock;

  lockGraph = import ./framework/lib/lock-drift.nix { inherit rootLock frameworkLock; };

  rootNixpkgs = lockGraph.resolvePath [ "nixpkgs" ];
  divergentNixpkgs =
    let
      visit = seen: path:
        let
          nodeId = lockGraph.resolvePath path;
          nodeInputs = rootLock.nodes.${nodeId}.inputs or { };
          nixpkgsPath = path ++ [ "nixpkgs" ];
        in
        if lib.elem nodeId seen then [ ] else
          lib.optional (nodeInputs ? nixpkgs && lockGraph.resolvePath nixpkgsPath != rootNixpkgs)
            (lib.concatStringsSep "/" nixpkgsPath)
          ++ lib.concatMap (name: visit (seen ++ [ nodeId ]) (path ++ [ name ]))
            (lib.attrNames nodeInputs);
    in visit [ ] [ ];
  nixpkgsCondition = "every input takes nixpkgs from the root"
    + lib.optionalString (divergentNixpkgs != [ ])
      " (different at: ${lib.concatStringsSep ", " divergentNixpkgs})";

  # --- accounts -----------------------------------------------------------
  # `{ }` without an account, so a missing one fails a condition instead of
  # the evaluation.
  login = host: user: hosts.${host}.users.users.${user} or { };
  account = host: user: {
    uid = (login host user).uid or null;
    description = (login host user).description or null;
    shell = inputs.framework.lib.accounts.shellIdentity ((login host user).shell or "none");
  };
  accountFile = user: import (./users + "/${user}/account.nix");

  hostsOf = user: lib.attrNames (lib.filterAttrs (_: host: host.hjem.users or { } ? ${user}) hosts);
  sameEverywhere = user:
    builtins.length (lib.unique (map (host: account host user) (hostsOf user))) == 1;

  # A compositor session reaches the user: framework/home/hyprland.nix
  # delivers it under ~/.config/hypr/.
  hasSession = host: user:
    lib.any (lib.hasPrefix ".config/hypr/") (lib.attrNames (hosts.${host}.hjem.users.${user}.homeMod.files or { }));

  # The `pkgs` the system hands its users' homeMod modules (through Hjem and
  # framework/adapters/hjem.nix). A submodule's value does not carry its
  # arguments, so they are read from the option type.
  userPkgs = host:
    (config.flake.nixosConfigurations.${host}.options.hjem.users.type.getSubOptions [ ]).homeMod.type.functor.payload.specialArgs.pkgs or { };
in
{
  perSystem = { pkgs, ... }: {
    checks.config = inputs.framework.lib.mkCheck pkgs "config" {
      "framework/flake.lock agrees with flake.lock at every shared input path (run `nix run .#sync-framework-lock`)" = lockGraph.drifted == [ ];
      ${nixpkgsCondition} = divergentNixpkgs == [ ];

      "black is deployed to both reference hosts" =
        lib.all (host: lib.elem host (hostsOf "black")) [ "desktop" "server" ];
      "black is the same account on every host" = sameEverywhere "black";
      "black's account comes from users/black/account.nix" =
        account "desktop" "black" == { inherit (accountFile "black") uid description shell; };
      "the host decides the groups" = lib.elem "wheel" ((login "desktop" "black").extraGroups or [ ]);

      "pkgs.unstable is a newer nixpkgs on every host" =
        lib.all (set: set ? unstable && lib.versionOlder set.lib.trivial.release set.unstable.lib.trivial.release)
          (lib.attrValues packages);
      "users inside NixOS see the same overlay" = userPkgs "desktop" ? unstable;

      "the server runs no compositor although black is deployed there" =
        !hosts.server.programs.hyprland.enable && !hosts.server.services.greetd.enable;
      "black's session is delivered on the workstation only" =
        hasSession "desktop" "black" && !(hasSession "server" "black");
      "no contract assertion fails" =
        lib.all (host: lib.all (assertion: assertion.assertion) host.assertions) (lib.attrValues hosts);
    };
  };
}
