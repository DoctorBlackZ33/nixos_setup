# Framework checks. Every condition is decided during evaluation and the
# derivations are empty markers, so `nix flake check --no-build` is the whole
# test run and a failure names the condition that broke.
{ pkgs, system, nixpkgs, inputs }:
let
  inherit (pkgs) lib;

  framework = import ../lib { inherit lib inputs; };
  inherit (framework) contract reconcile sections;

  mkCheck = name: conditions:
    let
      failed = lib.attrNames (lib.filterAttrs (_: holds: !holds) conditions);
    in
    assert lib.assertMsg (failed == [ ]) "check '${name}' failed: ${lib.concatStringsSep "; " failed}";
    pkgs.runCommand "check-${name}" { } "touch $out";

  fails = value: !(builtins.tryEval (builtins.deepSeq value value)).success;
  evaluates = derivation: builtins.isString derivation.drvPath;
  mentions = needle: lib.any (lib.hasInfix needle);

  # --- fixtures -----------------------------------------------------------
  hostFacts = {
    hostName = "fixture";
    platform = system;
    managed = "nixos";
    kind = "workstation";
    gpu.vendor = "amd";
  };

  facts = framework.facts.resolve {
    name = "fixture";
    facts = hostFacts;
  };

  provides = contract.evalProvides {
    pam.hyprlock = true;
    portals.hyprland = true;
    portals.gtk = true;
    services.hyprland = true;
    services.pipewire = true;
  };

  requires = contract.evalRequires;

  run = requests: reconcile.reconcile {
    host = "fixture";
    inherit requests provides facts;
  };

  # --- reconcile ----------------------------------------------------------
  clean = run {
    "user alice" = requires {
      pam.hyprlock = { };
      portals.hyprland = { };
      services.pipewire = { };
      facts."gpu.vendor" = { };
    };
  };

  misses = run {
    "user alice" = requires {
      services.hyprland = { };
      services.cups = { };
      portals.kde = { };
      secrets."wireguard/key" = { };
      facts."gpu.vulkan" = { };
      facts."displays" = { };
    };
  };

  optional = run {
    system = requires {
      services.cups.required = false;
      facts."location".required = false;
    };
  };

  shared = {
    "user alice" = requires {
      services.cups.required = false;
      secrets.token.mode = "0400";
    };
    "user bob" = requires {
      services.cups = { };
      secrets.token.mode = "0440";
    };
  };
  sharedWanted = reconcile.merge shared;
  sharedResult = run shared;

  noVulkan = reconcile.reconcile {
    host = "fixture";
    inherit provides;
    facts = framework.facts.resolve {
      name = "fixture";
      facts = hostFacts // { gpu.vulkan = false; };
    };
    requests.system = requires { facts."gpu.vulkan" = { }; };
  };

  # --- facts --------------------------------------------------------------
  detected = framework.facts.fromFacter {
    system = "aarch64-linux";
    virtualisation = "kvm";
    hardware = {
      graphics_card = [
        { vendor.value = 32902; }
        { vendor.value = 4318; }
      ];
      monitor = [
        {
          detail = {
            width = 2560;
            height = 1440;
          };
          resources = [
            {
              type = "monitor";
              width = 2560;
              height = 1440;
              vertical_frequency = 144;
            }
          ];
        }
      ];
    };
  };

  layered = framework.facts.resolve {
    name = "layered";
    facts = {
      hostName = "layered";
      managed = "manual";
      kind = "server";
      gpu.vendor = "amd";
    };
    report = {
      system = "x86_64-linux";
      virtualisation = "none";
      hardware.graphics_card = [ { vendor.value = 6900; } ];
    };
  };

  # --- user layer ---------------------------------------------------------
  evalHome = modules: framework.home.eval { inherit pkgs facts modules; };

  realised = home:
    lib.mapAttrs (_: source: "${source}") (framework.home.materialise pkgs home.files);

  programModules = lib.remove "core" (lib.attrNames framework.home.modules);

  hyprland = evalHome [
    {
      hyprland = {
        enable = true;
        settings.general.gaps_in = 5;
        fragments = [ "fragment.lua" ];
        startupCommands = [ "quickshell --config check" ];
        floatingToggleChord = "SUPER + SPACE";
      };
    }
  ];
  hyprlandLua = hyprland.files.".config/hypr/hyprland.lua".text;

  overridden = (evalHome [
    {
      hyprland.enable = true;
      hyprland.sections.policy = lib.mkForce {
        order = sections.order.early;
        text = "-- replaced";
      };
    }
  ]).files.".config/hypr/hyprland.lua".text;

  shell = evalHome [
    {
      environment.EDITOR = "nvim";
      fish.enable = true;
      fish.aliases.ll = "ls -lah";
      git.enable = true;
      gh.enable = true;
      direnv.enable = true;
      yazi.enable = true;
      yazi.settings.mgr.show_hidden = true;
      zoxide.enable = true;
    }
  ];
  fishConfig = shell.files.".config/fish/config.fish".text;

  # Sections as modules define them: through the option type.
  typedSections = definitions:
    (lib.evalModules {
      modules = [
        { options.sections = sections.option "fixture"; }
        { sections = definitions; }
      ];
    }).config.sections;

  bar = evalHome [
    {
      quickshell = {
        enable = true;
        activeConfig = "check";
        clockPrecision = "Seconds";
        label = "check";
      };
    }
  ];

  # --- synthetic fleet ----------------------------------------------------
  inventory = import ./fleet/deployments.nix;

  secrets = {
    directory = ./fleet/secrets;
    # Public half of a throwaway master key; see fleet/secrets/README.md.
    extraEncryptionPubkeys = [ "age173w2sh800fn48f3mz0grpp95sagfm7fh77rzl9gssw7lcm28eg9qwpe9ut" ];
  };

  buildFleet = { deployments, ... }@args: import ../lib/fleet.nix ({
    inherit lib framework inputs nixpkgs secrets;
    root = ./fleet;
  } // args // {
    deployments = framework.inventory.eval deployments;
  });
  fleetOf = deployments: buildFleet { inherit deployments; };

  fleet = fleetOf inventory.valid;
  rejected = name: fleetOf { ${name} = inventory.invalid.${name}; };
  rejectedNixos = name: (rejected name).nixosConfigurations.${name}.config;
  rejectedUser = name: user: (rejected name).verdicts."${user}@${name}";
  disabledUser = (fleetOf { inherit (inventory.edge) disabled-user; }).nixosConfigurations.disabled-user.config;
  withSecrets = backend: deployments: buildFleet {
    secrets = backend;
    inherit deployments;
  };
  secretHost = backend: (withSecrets backend { sec-1 = inventory.valid.sec-1; }).nixosConfigurations.sec-1.config;
  withoutCiphertext = secrets // { directory = ./fleet/users; };

  # Two requesters, one of them with nothing to complain about.
  uneven = run {
    "user alice" = requires { services.cups = { }; };
    "user bob" = requires { };
  };

  # frank's configuration needs an argument only `moduleArgs` supplies.
  withArgs = buildFleet {
    moduleArgs.greeting = "hello";
    deployments = {
      srv-1.users = [ "frank" ];
      man-srv.users = [ "frank" ];
    };
  };

  nixos = name: fleet.nixosConfigurations.${name}.config;
  home = name: fleet.hjemConfigurations.${name};
  targetsOf = name: map (file: file.target) (home name).manifest.files;
  hjemUser = host: user: (nixos host).hjem.users.${user};
  userFiles = host: user: (hjemUser host user).homeMod.files;
  systemPackages = name: map lib.getName (nixos name).environment.systemPackages;
  failing = config: map (assertion: assertion.message) (lib.filter (assertion: !assertion.assertion) config.assertions);

  serverWithDesktopUser = (rejected "nixos-server").nixosConfigurations.nixos-server;
in
{
  reconcile-clean = mkCheck "reconcile-clean" {
    "satisfied requests produce no errors" = clean.errors == [ ];
    "satisfied requests produce no warnings" = clean.warnings == [ ];
  };

  reconcile-required = mkCheck "reconcile-required" {
    "each miss is one error" = builtins.length misses.errors == 5;
    "a provided capability is not reported" = !(mentions "service 'hyprland'" misses.errors);
    "missing service" = mentions "service 'cups'" misses.errors;
    "missing portal" = mentions "portal 'kde'" misses.errors;
    "missing secret" = mentions "secret 'wireguard/key'" misses.errors;
    "unknown fact" = mentions "fact 'gpu.vulkan'" misses.errors;
    "empty fact" = mentions "fact 'displays'" misses.errors;
    "errors name the requester" = lib.all (lib.hasInfix "user alice") misses.errors;
    "errors name the host" = lib.all (lib.hasInfix "host 'fixture'") misses.errors;
    "a false fact counts as missing" = mentions "fact 'gpu.vulkan'" noVulkan.errors;
  };

  reconcile-optional = mkCheck "reconcile-optional" {
    "optional misses are not errors" = optional.errors == [ ];
    "optional misses warn" = builtins.length optional.warnings == 2;
    "warnings name the requester" = lib.all (lib.hasInfix "system") optional.warnings;
  };

  reconcile-shared = mkCheck "reconcile-shared" {
    "one requester needing it makes it required" = sharedWanted.services.cups.required;
    "every requester is kept" = sharedWanted.services.cups.sources == [ "user alice" "user bob" ];
    "the error lists every requester" = mentions "user alice, user bob" sharedResult.errors;
    "conflicting parameters are an error" = mentions "conflicting mode" sharedResult.errors;
    "a requester sees the conflicts it is part of" =
      mentions "conflicting mode" (sharedResult.forSources [ "user alice" ]).errors;
    "a requester sees its own misses" = (uneven.forSources [ "user alice" ]).errors != [ ];
    "and not what only others asked for" = (uneven.forSources [ "user bob" ]).errors == [ ];
  };

  contract-types = mkCheck "contract-types" {
    "requests default to required" = (requires { pam.hyprlock = { }; }).pam.hyprlock.required;
    "requests can be optional" = !(requires { portals.gtk.required = false; }).portals.gtk.required;
    "secrets default to owner-only" = (requires { secrets.token = { }; }).secrets.token.mode == "0400";
    "an unset requires has every kind" = requires { } == requires { services = { }; };
    "a bad secret mode is rejected" = fails (requires { secrets.token.mode = "rw"; });
    "an unknown capability kind is rejected" = fails (requires { service.cups = { }; });
    "an unknown provides kind is rejected" = fails (contract.evalProvides { service.cups = true; });
  };

  facts = mkCheck "facts" {
    "unknown facts are null, not guesses" = facts.location == null && facts.gpu.vulkan == null && facts.virtualisation == null;
    "the inventory key is a fact" = facts.name == "fixture";
    "an unknown kind is rejected" = fails (framework.facts.resolve {
      name = "bad";
      facts = hostFacts // { kind = "desktop"; };
    });
    "a host without a kind is rejected" = fails (framework.facts.resolve {
      name = "bad";
      facts = removeAttrs hostFacts [ "kind" ];
    });
    "report: platform" = detected.platform == "aarch64-linux";
    "report: hypervisor" = detected.virtualisation == "kvm";
    "report: the discrete card decides" = detected.gpu.vendor == "nvidia";
    "report: preferred mode with refresh" = detected.displays == [
      {
        width = 2560;
        height = 1440;
        refresh = 144;
      }
    ];
    "an unmeasured refresh rate stays unknown" =
      (framework.facts.resolve {
        name = "fixture";
        facts = hostFacts // { displays = [ { width = 1920; height = 1080; } ]; };
      }).displays == [ { width = 1920; height = 1080; refresh = null; } ];
    "report: an empty report claims nothing" = framework.facts.fromFacter { } == {
      gpu = { };
      displays = [ ];
    };
    "detected facts fill gaps" = layered.platform == "x86_64-linux";
    "bare metal has no hypervisor" = layered.virtualisation == null;
    "hand-written facts win" = layered.gpu.vendor == "amd";
  };

  sections = mkCheck "sections" {
    "order first, then name" =
      sections.render {
        sections = typedSections {
          b.text = "B";
          a.text = "A";
          z = { order = sections.order.early; text = "Z"; };
        };
      } == "Z\n\nA\n\nB";
    "headers are optional" =
      sections.render {
        comment = "#";
        sections = typedSections { only.text = "x"; };
      } == "# SECTION: only\nx";
    "a section can be disabled by name" =
      sections.render {
        sections = typedSections {
          kept.text = "kept";
          dropped = { enable = false; text = "dropped"; };
        };
      } == "kept";
  };

  home-hyprland = mkCheck "home-hyprland" {
    "settings are rendered as Lua" = lib.hasInfix "[\"gaps_in\"] = 5" hyprlandLua;
    "sections keep their order" =
      builtins.match ".*SECTION: settings.*SECTION: sources.*SECTION: policy.*SECTION: startup.*" hyprlandLua != null;
    "the chord is a value" = lib.hasInfix "hl.bind(\"SUPER + SPACE\"" hyprlandLua;
    "startup commands are emitted" = lib.hasInfix "quickshell --config check" hyprlandLua;
    "a section can be replaced by name" = lib.hasPrefix "-- SECTION: policy\n-- replaced" overridden;
    "it needs the compositor" = hyprland.requires.services ? hyprland;
    "it needs its portals" = hyprland.requires.portals ? hyprland && hyprland.requires.portals ? gtk;
    "it needs a GPU" = hyprland.requires.facts ? "gpu.vendor";
    "it installs no compositor package" = hyprland.packages == [ ];
  };

  home-shell = mkCheck "home-shell" {
    "aliases" = lib.hasInfix "alias ll 'ls -lah'" fishConfig;
    "environment reaches fish" = lib.hasInfix "set -gx EDITOR 'nvim'" fishConfig;
    "integrations follow settings, direnv last" =
      builtins.match ".*SECTION: settings.*SECTION: environment.*SECTION: yazi.*SECTION: zoxide.*SECTION: direnv.*" fishConfig != null;
    "gh becomes the git credential helper" =
      lib.hasSuffix "/bin/gh auth git-credential"
        (lib.last shell.git.settings.credential."https://github.com".helper);
    "settings become a generated file" = shell.files ? ".config/yazi/yazi.toml";
    "no settings, no file" = !((evalHome [ { yazi.enable = true; } ]).files ? ".config/yazi/yazi.toml");
    "files are relative to the home directory" = lib.all (lib.hasPrefix ".config/") (lib.attrNames shell.files);
    "every file realises without evaluation-time builds" = lib.all lib.isString (lib.attrValues (realised shell));
    "a file outside the home directory is rejected" =
      fails (evalHome [ { files."../outside".text = "x"; } ]).files
      && fails (evalHome [ { files."/etc/outside".text = "x"; } ]).files;
    "a file with both text and source is rejected" =
      fails (evalHome [ { files."both" = { text = "x"; source = ./default.nix; }; } ]).files;
    "without a secrets backend there is no secret path" = fails (shell.secretPath "token");
    "a misspelled option is rejected" = fails (evalHome [
      {
        fish.enable = true;
        fish.alaises.ll = "ls";
      }
    ]).files;
  };

  home-quickshell = mkCheck "home-quickshell" {
    "policy is generated" =
      lib.hasInfix "clockPrecision: SystemClock.Seconds" bar.files.".config/quickshell/check/DesktopPolicy.qml".text;
    "the label is quoted" = lib.hasInfix "label: \"check\"" bar.files.".config/quickshell/check/DesktopPolicy.qml".text;
    "an invalid precision is rejected" = fails (evalHome [
      {
        quickshell.enable = true;
        quickshell.clockPrecision = "Sometimes";
      }
    ]).files;
    "it asks nothing from the host" = bar.requires == requires { };
  };
}
// lib.listToAttrs (map
  # Spec section 12: every program module evaluates on its own.
  (name: lib.nameValuePair "home-module-${name}" (mkCheck "home-module-${name}" {
    "enabling only ${name} evaluates" =
      let
        enabled = evalHome [ { ${name}.enable = true; } ];
      in
      lib.all lib.isString (lib.attrValues (realised enabled))
      && lib.all evaluates enabled.packages
      && enabled.requires ? services;
  }))
  programModules)
// {
  fleet-nixos = mkCheck "fleet-nixos" {
    "a desktop user gets the compositor on a workstation" = (nixos "ws-1").programs.hyprland.enable;
    "her portals are provided" = (nixos "ws-1").contract.provides.portals.hyprland && (nixos "ws-1").contract.provides.portals.gtk;
    "every user is a named requester" =
      lib.attrNames (nixos "ws-1").contract.requests == [ "system" "user alice" "user bob" ];
    "the contract holds" = failing (nixos "ws-1") == [ ];
    "files are delivered through Hjem" =
      lib.hasPrefix builtins.storeDir
        "${(hjemUser "ws-1" "alice").files.".config/hypr/hyprland.lua".source or ""}";
    "packages are delivered through Hjem" = lib.elem "fish" (map lib.getName (hjemUser "ws-1" "alice").packages);
    "environment is delivered through Hjem" =
      ((hjemUser "ws-1" "alice").environment.sessionVariables.EDITOR or null) == "vi";
    "a host can ask for audio itself" =
      (nixos "ws-3").services.pipewire.enable && (nixos "ws-3").security.rtkit.enable && !(nixos "ws-3").programs.hyprland.enable;
    "a host override reaches the user" =
      lib.hasInfix "SUPER + SPACE" (userFiles "ws-2" "alice").".config/hypr/hyprland.lua".text;
    "the greeter follows the compositor" =
      lib.hasInfix "start-hyprland" (nixos "ws-2").services.greetd.settings.default_session.command;
    "development tools are opt-in" = lib.elem "gcc-wrapper" (systemPackages "ws-2") && !(lib.elem "gcc-wrapper" (systemPackages "ws-1"));
    "identity comes from facts" = (nixos "ws-1").networking.hostName == "ws-1";
  };

  fleet-servers = mkCheck "fleet-servers" {
    "a server without users evaluates" = evaluates fleet.nixosConfigurations.srv-1.config.system.build.toplevel;
    "a server stays headless" =
      !(nixos "srv-2").programs.hyprland.enable && !(nixos "srv-2").hardware.graphics.enable && !(nixos "srv-2").services.pipewire.enable;
    "a server gets no compilers" = !(lib.elem "gcc-wrapper" (systemPackages "srv-2"));
    "a server runs sshd with keys only" =
      (nixos "srv-1").services.openssh.enable && !(nixos "srv-1").services.openssh.settings.PasswordAuthentication;
    "a server uses networkd" = (nixos "srv-1").networking.useNetworkd && !(nixos "srv-1").networking.networkmanager.enable;
    "a workstation uses NetworkManager" = (nixos "ws-1").networking.networkmanager.enable;
    "a gated desktop user is harmless on a server" =
      !(nixos "srv-arm").programs.hyprland.enable && !((userFiles "srv-arm" "alice") ? ".config/hypr/hyprland.lua");
    "another architecture evaluates from here" =
      (nixos "srv-arm").nixpkgs.hostPlatform.system == "aarch64-linux"
      && evaluates fleet.nixosConfigurations.srv-arm.config.system.build.toplevel;
  };

  fleet-refusal = mkCheck "fleet-refusal" {
    "NixOS server: the error names user and host" =
      mentions "service 'hyprland' is requested by user carol but host 'nixos-server' does not provide it"
        (failing serverWithDesktopUser.config);
    "NixOS server: the system does not build" = fails serverWithDesktopUser.config.system.build.toplevel.drvPath;
    "NixOS server: no compositor was enabled" = !serverWithDesktopUser.config.programs.hyprland.enable;
    "system-manager server refuses the user who asked" =
      mentions "service 'hyprland' is requested by user carol but host 'system-manager-server' does not provide it"
        (rejectedUser "system-manager-server" "carol").errors
      && fails (rejected "system-manager-server").hjemConfigurations."carol@system-manager-server".manifest.version;
    "its system and its other users still build" =
      evaluates (rejected "system-manager-server").systemConfigs.system-manager-server
      && (rejected "system-manager-server").hjemConfigurations."bob@system-manager-server".manifest.version == 3;
    "manual server refuses the user who asked" =
      mentions "requested by user carol but host 'manual-server'" (rejectedUser "manual-server" "carol").errors
      && fails (rejected "manual-server").hjemConfigurations."carol@manual-server".manifest.version;
    "and nobody else on that host" =
      (rejected "manual-server").hjemConfigurations."bob@manual-server".manifest.version == 3;
    "users of one host who disagree are both refused" =
      mentions "conflicting mode" (rejectedUser "manual-conflict" "gina").errors
      && mentions "conflicting mode" (rejectedUser "manual-conflict" "hugo").errors;
    "alone, the same optional request only warns" =
      let
        alone = (fleetOf { man-srv.users = [ "gina" ]; }).verdicts."gina@man-srv";
      in
      alone.errors == [ ] && builtins.length alone.warnings == 1;
    "a user switched off in Hjem asks for nothing" =
      failing disabledUser == [ ] && !disabledUser.programs.hyprland.enable;
    "a deployed user without an account is reported as such" =
      mentions "user 'erin' is deployed here but has no" (failing (rejectedNixos "no-account"));
    "a host may not contradict its facts" =
      mentions "hostName fact is \"bad-name\"" (failing (rejectedNixos "identity-mismatch"));
    "a host may not rewrite its facts" = fails (rejectedNixos "facts-override").contract.facts.kind;
    "a manual host may not claim secrets" =
      fails (rejected "manual-secret").hjemConfigurations."bob@manual-secret".manifest.version;
  };

  fleet-secrets = mkCheck "fleet-secrets" {
    "a requested secret is declared for agenix" = (nixos "sec-1").age.secrets ? demo-token;
    "it belongs to the one user who asked" = (nixos "sec-1").age.secrets.demo-token.owner == "dave";
    "it has the requested mode" = (nixos "sec-1").age.secrets.demo-token.mode == "0400";
    "the user layer gets a path, not a value" =
      (userFiles "sec-1" "dave").".config/demo/env".text == "TOKEN_FILE=/run/agenix/demo-token";
    "the contract holds" = failing (nixos "sec-1") == [ ];
    "hosts without requests declare no secret" = (nixos "srv-2").age.secrets == { };
    "without a backend the secret is refused" =
      mentions "secret 'demo-token' is requested by user dave but host 'sec-1' does not provide it"
        (failing (secretHost null));
    "without its ciphertext the secret is refused" =
      mentions "secret 'demo-token'" (failing (secretHost withoutCiphertext));
    "a secret has exactly one reader" =
      mentions "secret 'demo-token' is requested by user dana, user dave" (failing (rejectedNixos "shared-secret"));
    "and that holds before the ciphertext exists" =
      mentions "exactly one reader"
        (failing (withSecrets withoutCiphertext { inherit (inventory.invalid) shared-secret; }).nixosConfigurations.shared-secret.config);
  };

  # The one check that needs a build: the copy `agenix rekey` produced for
  # the fixture host must open with that host's key.
  fleet-secret-decrypts = pkgs.runCommand "check-fleet-secret-decrypts"
    { nativeBuildInputs = [ pkgs.rage ]; }
    ''
      install -m 600 ${./fleet/secrets/fixture-host-key} key
      test "$(rage -d -i key ${(nixos "sec-1").age.secrets.demo-token.file})" = "fixture value, used by no host"
      touch $out
    '';

  fleet-foreign = mkCheck "fleet-foreign" {
    "system-manager configs evaluate" =
      lib.all evaluates [ fleet.systemConfigs.sm-ws fleet.systemConfigs.sm-srv fleet.systemConfigs.sm-arm ];
    "system-manager reconciles for standalone users" =
      lib.attrNames fleet.systemConfigs.sm-ws.config.contract.requests == [ "system" "user alice" ];
    "a declared capability satisfies them" = (home "alice@sm-ws").manifest.version == 3;
    "files land in the user's home" = lib.elem "/home/alice/.config/hypr/hyprland.lua" (targetsOf "alice@sm-ws");
    "a manual host uses its declared provides" = lib.elem "/home/alice/.config/hypr/hyprland.lua" (targetsOf "alice@man-ws");
    "a host override applies off NixOS too" = lib.elem "/home/alice/.config/demo/host" (targetsOf "alice@man-ws");
    "home directories can be overridden" = lib.all (lib.hasPrefix "/srv/home/bob/") (targetsOf "bob@man-srv");
    "packages travel with the configuration" = lib.elem "fish" (map lib.getName (home "bob@man-srv").packages);
    "environment becomes an environment.d file" =
      lib.elem "/home/alice/.config/environment.d/60-home.conf" (targetsOf "alice@man-ws");
    "NixOS users are not exported standalone" = !(fleet.hjemConfigurations ? "alice@ws-1");
    "another architecture uses its own packages" =
      lib.all (package: package.system == "aarch64-linux") (home "bob@man-arm").packages;
  };

  fleet-inventory = mkCheck "fleet-inventory" {
    "thirteen hosts, three ways of managing them" =
      lib.length (lib.attrNames fleet.nixosConfigurations) == 7
      && lib.length (lib.attrNames fleet.systemConfigs) == 3
      && lib.length (lib.attrNames fleet.hjemConfigurations) == 5;
    "systems come from the facts" = lib.sort lib.lessThan fleet.systems == [ "aarch64-linux" "x86_64-linux" ];
    "every deployable thing has its own check" =
      lib.attrNames (fleet.checksFor "aarch64-linux") == [ "home-bob@man-arm" "nixos-srv-arm" "system-sm-arm" ];
    "every check derivation evaluates" =
      lib.all (platform: lib.all evaluates (lib.attrValues (fleet.checksFor platform))) fleet.systems;
    "an unknown user is rejected" = fails (fleetOf { ws-1.users = [ "nobody" ]; }).nixosConfigurations.ws-1.config.networking.hostName;
    "an unknown host is rejected" = fails (lib.attrNames (fleetOf { ghost = { }; }).nixosConfigurations);
    "a misspelled inventory field is rejected" = fails (fleetOf { ws-1.user = [ "alice" ]; }).systems;
    "two deployments of one host are rejected" =
      fails (lib.attrNames (fleetOf {
        first.host = "srv-1";
        second.host = "srv-1";
      }).nixosConfigurations);
    "a user listed twice is rejected" =
      fails (fleetOf { ws-1.users = [ "alice" "alice" ]; }).nixosConfigurations.ws-1.config.networking.hostName;
    "a home for an unlisted user is rejected" =
      fails (fleetOf { man-srv = { users = [ "bob" ]; homes.bbo = "/srv/home/bob"; }; }).hjemConfigurations."bob@man-srv".manifest.version;
    "a relative home is rejected" =
      fails (fleetOf { man-srv = { users = [ "bob" ]; homes.bob = "srv/home/bob"; }; }).hjemConfigurations."bob@man-srv".manifest.version;
    "a home override on a NixOS host is rejected" =
      fails (fleetOf { ws-1 = { users = [ "alice" ]; homes.alice = "/srv/alice"; }; }).nixosConfigurations.ws-1.config.networking.hostName;
    "moduleArgs reach users inside NixOS" =
      withArgs.nixosConfigurations.srv-1.config.hjem.users.frank.homeMod.files.".config/demo/greeting".text == "hello";
    "moduleArgs reach standalone users" =
      lib.any (file: file.target == "/home/frank/.config/demo/greeting") withArgs.hjemConfigurations."frank@man-srv".manifest.files;
    "moduleArgs may not shadow framework arguments" =
      fails (lib.attrNames (buildFleet {
        moduleArgs.facts = { };
        deployments.srv-1 = { };
      }).nixosConfigurations);
  };
}
// lib.mapAttrs'
  (name: configuration:
    lib.nameValuePair "fleet-host-${name}" (mkCheck "fleet-host-${name}" {
      "${name} evaluates to a system" = evaluates configuration.config.system.build.toplevel;
    }))
  fleet.nixosConfigurations
