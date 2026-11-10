{ nixpkgs, hjem }:
let
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; };
  pm = import ./. { inherit (pkgs) lib; };
  inherit (pm.lib.programmod) dag renderSections;

  standalone = modules: pm.configuration { inherit pkgs modules; };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;

  missingHints = dag.topoSort {
    first = dag.entryAfter [ "not-defined" ] "first";
    second = dag.entryBefore [ "also-not-defined" ] "second";
  };
  cycle = dag.topoSort {
    first = dag.entryAfter [ "second" ] "first";
    second = dag.entryAfter [ "first" ] "second";
  };

  ordered = standalone [
    {
      git.enable = true;
      git.package = null;
      git.sections = {
        first = dag.entryBefore [ "shared" "not-defined" ] "before";
        shared = dag.entryAfter [ "first" "not-defined" ] "one";
        last = dag.entryAfter [ "shared" ] "after";
      };
    }
    { git.sections.shared = dag.entryAfter [ "first" "also-not-defined" ] "two"; }
  ];

  mergedText = standalone [
    { files."programmod-test/merged.conf".text = "first"; }
    { files."programmod-test/merged.conf".text = "second"; }
  ];
  conflictingEnvironment = standalone [
    { environment.PROGRAMMOD_TEST = "first"; }
    { environment.PROGRAMMOD_TEST = "second"; }
  ];
  bothTextAndSource = standalone [
    { files."programmod-test/both.conf" = { text = "invalid"; source = ./test.nix; }; }
  ];
  neitherTextNorSource = standalone [
    { files."programmod-test/neither.conf" = { }; }
  ];
  wrongClass = standalone [ { _class = "nixos"; } ];
  disabled = standalone [ { git.package = null; } ];
  enabledWithoutPackage = standalone [ { git.enable = true; git.package = null; } ];

  nixos = { userEnabled, hyprlandEnabled }:
    import (nixpkgs + "/nixos/lib/eval-config.nix") {
      inherit system;
      modules = [
        (import (hjem + "/modules/nixos")).default
        ./adapters/nixos.nix
        ({ ... }: {
          users.users."programmod-test".isNormalUser = true;
          hjem.users."programmod-test" = {
            enable = userEnabled;
            user = "programmod-test";
            directory = "/home/programmod-test";
            homeMod = {
              git.enable = true;
              git.settings.credential."https://github.com".helper = [ "user-defined" ];
              gh.enable = true;
              hyprland.enable = hyprlandEnabled;
              environment.PROGRAMMOD_TEST = "from-programmod";
            };
          };
        })
        {
          system.stateVersion = "26.05";
          fileSystems."/" = { device = "/dev/null"; fsType = "ext4"; };
          boot.loader.grub.enable = false;
        }
      ];
    };
  enabledSystem = nixos { userEnabled = true; hyprlandEnabled = true; };
  disabledSystem = nixos { userEnabled = false; hyprlandEnabled = true; };
  enabledUser = enabledSystem.config.hjem.users."programmod-test";

  checks = {
    dagOrderAndMergedSectionData =
      renderSections { sections = ordered.git.sections; } == "before\none\ntwo\nafter";
    missingOrderingHintsAreIgnored = missingHints ? result
      && builtins.sort builtins.lessThan (map (entry: entry.name) missingHints.result)
        == [ "first" "second" ];
    cycleIsReportedByTopoSort = cycle ? cycle && cycle ? loops && !(cycle ? result);
    conflictingEnvironmentIsRejected = rejects conflictingEnvironment.environment.PROGRAMMOD_TEST;
    samePathTextLinesMerge = mergedText.files."programmod-test/merged.conf".text == "first\nsecond";
    bothTextAndSourceAreRejected = rejects bothTextAndSource.files;
    neitherTextNorSourceAreRejected = rejects neitherTextNorSource.files;
    wrongModuleClassIsRejected = rejects wrongClass.files;
    disabledProgramEmitsNothing = disabled.files == { } && disabled.packages == [ ];
    enabledNullPackageEmitsConfigOnly = enabledWithoutPackage.files ? "git/config"
      && enabledWithoutPackage.packages == [ ];
    enabledHjemUserEnablesHyprland = enabledSystem.config.programs.hyprland.enable;
    disabledHjemUserDoesNotEnableHyprland = !disabledSystem.config.programs.hyprland.enable;
    explicitGitSettingOverridesGhDefault =
      enabledUser.homeMod.git.settings.credential."https://github.com".helper == [ "user-defined" ];
  };
in
assert builtins.all (check: check) (builtins.attrValues checks);
{ ok = true; }
