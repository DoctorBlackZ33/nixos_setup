# Inventory + config tree -> outputs. `deployments` says which users run on
# which host; `hosts/<host>/facts.nix` says what the host is, and its `managed`
# fact alone selects the adapters:
#
#   nixos           NixOS system, users through Hjem inside it
#   system-manager  system-manager config, users through `hjem standalone`
#   manual          no system output, users through `hjem standalone`
#
# The real config flake and the synthetic fleet in framework/checks both go
# through this function.
{ lib, framework, inputs, nixpkgs, root, deployments, secrets ? null, moduleArgs ? { } }:
let
  inherit (framework.modules) discover;

  hostsDirectory = root + "/hosts";
  usersDirectory = root + "/users";

  directoriesWith = file: directory:
    lib.attrNames (lib.filterAttrs
      (name: type: type == "directory" && builtins.pathExists (directory + "/${name}/${file}"))
      (builtins.readDir directory));

  knownHosts = directoriesWith "facts.nix" hostsDirectory;
  knownUsers = directoriesWith "default.nix" usersDirectory;

  commonSystemModules = lib.attrValues (discover ../system/common);
  nixosSystemModules = lib.attrValues (discover ../system/nixos);

  standalone = import ../adapters/standalone.nix { inherit lib framework; };

  fail = subject: problems:
    throw (lib.concatStringsSep "\n" ([ "${subject}:" ] ++ map (problem: "  - ${problem}") problems));

  # Arguments the framework hands to modules itself; `moduleArgs` may not
  # shadow them.
  reservedArgs = [ "framework" "pkgs" "facts" "inputs" "secretsDirectory" "osConfig" ];
  shadowedArgs = lib.intersectLists reservedArgs (lib.attrNames moduleArgs);
  systemArgs = moduleArgs // { inherit framework; };

  mkTarget = name: entry:
    let
      host = if entry.host != null then entry.host else name;
      directory = hostsDirectory + "/${host}";
      systemPath = directory + "/default.nix";
      providesPath = directory + "/provides.nix";
      reportPath = directory + "/facter.json";

      facts =
        if lib.elem host knownHosts then
          framework.facts.resolve {
            inherit name;
            facts = import (directory + "/facts.nix");
            report = if builtins.pathExists reportPath then lib.importJSON reportPath else null;
          }
        else
          fail "deployment '${name}'" [
            "hosts/${host}/facts.nix does not exist (known hosts: ${lib.concatStringsSep ", " knownHosts})"
          ];

      inherit (facts) managed;

      declaredProvides =
        framework.contract.evalProvides (if builtins.pathExists providesPath then import providesPath else { });

      homeNames = lib.attrNames entry.homes;

      problems =
        map
          (user: "users/${user}/default.nix does not exist (known users: ${lib.concatStringsSep ", " knownUsers})")
          (lib.filter (user: !(lib.elem user knownUsers)) (lib.unique entry.users))
        ++ map (user: "user '${user}' is listed more than once")
          (lib.unique (lib.filter (user: lib.count (other: other == user) entry.users > 1) entry.users))
        ++ map (user: "homes.${user} is set, but '${user}' is not one of the users")
          (lib.filter (user: !(lib.elem user entry.users)) homeNames)
        ++ map (user: "homes.${user} = \"${entry.homes.${user}}\" is not an absolute path")
          (lib.filter (user: !(lib.hasPrefix "/" entry.homes.${user})) homeNames)
        ++ lib.optional (managed == "nixos" && entry.homes != { })
          "homes is set, but on a NixOS host the home directory belongs to the account (users.users.<name>.home)"
        ++ lib.optional (managed != "manual" && !(builtins.pathExists systemPath))
          "hosts/${host}/default.nix is missing, but the host is managed by ${managed}"
        ++ lib.optional (managed == "manual" && builtins.pathExists systemPath)
          "hosts/${host}/default.nix exists, but a manual host has no system evaluation that would use it"
        ++ lib.optional (managed != "manual" && builtins.pathExists providesPath)
          "hosts/${host}/provides.nix exists, but a ${managed} host computes what it provides"
        ++ lib.optional (managed == "manual" && declaredProvides.secrets != { })
          "hosts/${host}/provides.nix declares secrets, but only NixOS hosts have a secrets backend";

      checked = value: if problems == [ ] then value else fail "deployment '${name}'" problems;

      # R7: one override file per user and host, used by every adapter.
      homeModules = user:
        let
          override = directory + "/users/${user}.nix";
        in
        [ (usersDirectory + "/${user}") ] ++ lib.optional (builtins.pathExists override) override;

      # --- NixOS ----------------------------------------------------------
      nixos = nixpkgs.lib.nixosSystem {
        specialArgs = systemArgs;
        modules =
          [ ../adapters/nixos.nix ]
          ++ commonSystemModules
          ++ nixosSystemModules
          ++ [
            systemPath
            { contract.facts = facts; }
          ]
          # R1: which modules exist follows from the inventory and from flake
          # settings, never from this evaluation's config.
          ++ lib.optionals (entry.users != [ ]) [
            inputs.hjem.nixosModules.default
            ../adapters/nixos-users.nix
            {
              hjem.specialArgs = { inherit moduleArgs; };
              hjem.users = lib.genAttrs entry.users (user: { homeMod.imports = homeModules user; });
            }
          ]
          ++ lib.optionals (secrets != null) [
            inputs.agenix.nixosModules.default
            inputs.agenix-rekey.nixosModules.default
            ../system/optional/agenix.nix
            { sysMod.secrets = secrets; }
          ];
      };

      # --- everything else: users are evaluated on their own --------------
      homeConfigs = lib.genAttrs entry.users (user: framework.home.eval {
        pkgs = nixpkgs.legacyPackages.${facts.platform};
        inherit facts moduleArgs;
        modules = homeModules user;
      });

      # All users of the host reconcile together, so two of them disagreeing
      # is caught here exactly as it is inside a NixOS evaluation.
      requests = lib.mapAttrs' (user: home: lib.nameValuePair "user ${user}" home.requires) homeConfigs;

      system = inputs.system-manager.lib.makeSystemConfig {
        specialArgs = systemArgs;
        modules =
          [ ../adapters/system-manager.nix ]
          ++ commonSystemModules
          ++ [
            systemPath
            {
              contract.facts = facts;
              contract.userRequests = lib.mapAttrs (_: home: home.requires) homeConfigs;
            }
          ];
      };

      # What standalone users reconcile against: computed by system-manager,
      # or declared by hand for a host nobody manages.
      provides = if managed == "system-manager" then system.config.contract.provides else declaredProvides;

      homes = lib.mapAttrs
        (user: homeMod: standalone.mkConfiguration {
          pkgs = nixpkgs.legacyPackages.${facts.platform};
          inherit facts provides requests user homeMod;
          home = entry.homes.${user} or "/home/${user}";
        })
        homeConfigs;
    in
    {
      inherit name facts;
      nixos = checked nixos;
      system = checked system;
      homes = checked homes;
    };

  targets = lib.mapAttrs mkTarget deployments;

  duplicateHostNames =
    lib.attrNames (lib.filterAttrs (_: names: builtins.length names > 1)
      (lib.groupBy (name: targets.${name}.facts.hostName) (lib.attrNames targets)));

  inventoryProblems =
    map (hostName: "host name '${hostName}' is used by more than one deployment") duplicateHostNames
    ++ map (arg: "moduleArgs.${arg} would shadow an argument the framework provides") shadowedArgs;

  guard = value: if inventoryProblems == [ ] then value else fail "inventory" inventoryProblems;

  managedBy = managed: lib.filterAttrs (_: target: target.facts.managed == managed) targets;
  standaloneTargets = lib.filterAttrs (_: target: target.facts.managed != "nixos") targets;
in
{
  systems = lib.unique (lib.mapAttrsToList (_: target: target.facts.platform) targets);

  nixosConfigurations = guard (lib.mapAttrs (_: target: target.nixos) (managedBy "nixos"));

  systemConfigs = guard (lib.mapAttrs (_: target: target.system) (managedBy "system-manager"));

  # `hjem standalone switch --flake . --flake-attr 'hjemConfigurations."<user>@<name>"'`
  hjemConfigurations = guard (lib.concatMapAttrs
    (name: target:
      lib.mapAttrs' (user: home: lib.nameValuePair "${user}@${name}" home.configuration) target.homes)
    standaloneTargets);

  # The same users' contract verdicts as data: `{ errors; warnings; }`.
  verdicts = guard (lib.concatMapAttrs
    (name: target:
      lib.mapAttrs' (user: home: lib.nameValuePair "${user}@${name}" home.verdict) target.homes)
    standaloneTargets);

  # One check per deployable thing, so a failure names its host and CI can
  # build them independently. NixOS checks are the system toplevels.
  checksFor = system:
    guard (lib.concatMapAttrs
      (name: target:
        if target.facts.managed == "nixos" then
          { "nixos-${name}" = target.nixos.config.system.build.toplevel; }
        else
          lib.optionalAttrs (target.facts.managed == "system-manager") { "system-${name}" = target.system; }
          // lib.mapAttrs'
            (user: home: lib.nameValuePair "home-${user}@${name}" (builtins.seq home.configuration home.closure))
            target.homes)
      (lib.filterAttrs (_: target: target.facts.platform == system) targets));
}
