# Standalone adapter: one user's evaluated homeMod on a host whose system is
# not a NixOS evaluation. It returns exactly the value `hjem standalone
# switch` consumes (a version 3 manifest plus packages), so activation,
# generations and rollback are Hjem's.
{ lib, framework }:
{
  # `requests` holds every user of the host, so users who disagree are caught
  # here as they are inside a NixOS evaluation. The verdict is then narrowed
  # to this user: someone else's unmet request does not block them.
  mkConfiguration = { pkgs, facts, provides, requests, user, home, homeMod }:
    let
      result = (framework.reconcile.reconcile {
        host = facts.name;
        inherit requests provides facts;
      }).forSources [ "user ${user}" ];

      # Hjem's manifest has no field for environment variables. systemd user
      # sessions read ~/.config/environment.d; shells that do not are served
      # by their own module (see framework/home/fish.nix).
      environmentFile = lib.optionalAttrs (homeMod.environment != { }) {
        ".config/environment.d/60-home.conf" = pkgs.writeText "60-home.conf"
          (lib.concatStrings (lib.mapAttrsToList
            (name: value: "${name}=${builtins.toJSON value}\n")
            homeMod.environment));
      };

      sources = framework.home.materialise pkgs homeMod.files // environmentFile;

      configuration = {
        manifest = {
          version = 3;
          files = lib.mapAttrsToList
            (path: source: {
              type = "symlink";
              source = "${source}";
              target = "${home}/${path}";
            })
            sources;
        };
        inherit (homeMod) packages;
      };
    in
    {
      # The verdict as data, for checks and for asking why something fails.
      verdict = result;

      # Forced by the flake output: errors throw, warnings trace (spec 7.4).
      configuration =
        if result.errors != [ ] then
          throw (framework.reconcile.report facts.name result.errors)
        else
          lib.foldr lib.warn configuration result.warnings;

      # One derivation that realises every file and package, for checks.
      closure = pkgs.linkFarm "home-${user}-${facts.name}" (
        lib.mapAttrsToList (path: source: { name = "files/${path}"; path = source; }) sources
        ++ lib.imap0 (index: package: { name = "packages/${toString index}"; path = package; }) homeMod.packages
      );
    };
}
