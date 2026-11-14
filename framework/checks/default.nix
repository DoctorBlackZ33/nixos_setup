# Framework checks: reconcile fixtures, contract types, and one evalModules
# test for the home module set. These run at evaluation time of `nix flake
# check`; the derivations themselves are empty.
{ ... }:
{
  perSystem = { pkgs, ... }:
    let
      inherit (pkgs) lib;

      reconcileLib = import ../lib/reconcile.nix { inherit lib; };

      mkCheck = name: condition:
        assert lib.assertMsg condition "framework check '${name}' failed";
        pkgs.runCommand "check-${name}" { } "touch $out";

      homeModuleFiles = builtins.filter
        (name: lib.hasSuffix ".nix" name && name != "core.nix")
        (builtins.attrNames (builtins.readDir ../home));

      fixtureFacts = {
        hostName = "check-host";
        platform = "x86_64-linux";
        location = "ci";
        managed = "nixos";
        gpu.vendor = "virtual";
        displays = [ { width = 1920; height = 1080; } ];
      };

      fixtureProvides = {
        pam.hyprlock = true;
        portals = [ "hyprland" "gtk" ];
        services.hyprland = true;
        services.pipewire = true;
      };

      # --- reconcile ------------------------------------------------------
      clean = reconcileLib.reconcile {
        requires = {
          pam.hyprlock = { };
          portals = [ "hyprland" ];
          services.pipewire = { };
          facts."gpu.vendor" = { };
        };
        provides = fixtureProvides;
        facts = fixtureFacts;
      };

      missingRequired = reconcileLib.reconcile {
        requires = {
          services.hyprland = { };
          services.cups = { };
          portals = [ "hyprland" "kde" ];
          secrets."wireguard/key" = { };
          facts."gpu.vendor" = { };
          facts."displays" = { };
        };
        provides = fixtureProvides;
        facts = fixtureFacts // { displays = [ ]; };
      };

      optionalMissing = reconcileLib.reconcile {
        requires = {
          services.cups = { required = false; };
          facts."gpu.vulkan" = { required = false; };
        };
        provides = fixtureProvides;
        facts = fixtureFacts;
      };

      # --- contract types -------------------------------------------------
      evalRequires = definition: (lib.evalModules {
        class = "homeMod";
        modules = [ ../home/core.nix { requires = definition; } ];
      }).config.requires;

      typedRequires = evalRequires {
        pam.hyprlock = { };
        portals = [ "hyprland" "gtk" ];
        services.pipewire = { required = false; };
        udev.rules = [ "KERNEL==\"kvm\", MODE=\"0666\"" ];
        setuid."mount.cifs" = { };
        secrets."wireguard/key" = { mode = "0400"; };
        facts."gpu.vulkan" = { required = false; };
      };

      # --- home module set ------------------------------------------------
      homeTest = (lib.evalModules {
        class = "homeMod";
        specialArgs = { facts = fixtureFacts; inherit pkgs; };
        modules = [ ../home/core.nix ]
          ++ map (name: ../home + "/${name}") homeModuleFiles
          ++ [
          {
            fish.enable = true;
            fish.settings.aliases.ll = "ls -lah";
            git.enable = true;
            git.settings.user.name = "Check User";
            gh.enable = true;
            direnv.enable = true;
            yazi.enable = true;
            zoxide.enable = true;
            fuzzel.enable = true;
            mako.enable = true;
            hyprland.enable = true;
            hyprland.floatingToggleChord = "SUPER + SPACE";
            hyprland.settings.general.gaps_in = 5;
            hyprland.fragments = [ "fragment.lua" ];
            hyprland.startupCommands = [ "quickshell --config check" ];
            quickshell = {
              enable = true;
              activeConfig = "check";
              label = "check";
            };
            environment.EDITOR = "nvim";
          }
        ];
      }).config;

      homeReconcile = reconcileLib.reconcile {
        requires = homeTest.requires;
        provides = fixtureProvides;
        facts = fixtureFacts;
      };

      hyprlandLua = homeTest.files."hypr/hyprland.lua".text;
      fishConfig = homeTest.files."fish/config.fish".text;
      policyQml = homeTest.files."quickshell/check/DesktopPolicy.qml".text;
    in
    {
      checks = {
        reconcile-clean = mkCheck "reconcile-clean"
          (clean.errors == [ ] && clean.warnings == [ ]);

        reconcile-required = mkCheck "reconcile-required" (
          lib.length missingRequired.errors == 4
          && lib.any (error: lib.hasInfix "service 'cups'" error) missingRequired.errors
          && lib.any (error: lib.hasInfix "portal 'kde'" error) missingRequired.errors
          && lib.any (error: lib.hasInfix "secret 'wireguard/key'" error) missingRequired.errors
          && lib.any (error: lib.hasInfix "fact 'displays'" error) missingRequired.errors
          && missingRequired.warnings == [ ]
        );

        reconcile-optional = mkCheck "reconcile-optional" (
          optionalMissing.errors == [ ]
          && lib.length optionalMissing.warnings == 2
          && lib.any (warning: lib.hasInfix "service 'cups'" warning) optionalMissing.warnings
          && lib.any (warning: lib.hasInfix "fact 'gpu.vulkan'" warning) optionalMissing.warnings
        );

        contract-types = mkCheck "contract-types" (
          typedRequires.pam.hyprlock.required
          && !typedRequires.services.pipewire.required
          && typedRequires.secrets."wireguard/key".mode == "0400"
          && typedRequires.udev.rules != [ ]
          && typedRequires.setuid."mount.cifs".required
        );

        home-modules = mkCheck "home-modules" (
          homeReconcile.errors == [ ]
          && homeReconcile.warnings == [ ]
          && homeTest.requires.services ? hyprland
          && homeTest.requires.services ? pipewire
          && lib.elem "hyprland" homeTest.requires.portals
          && homeTest.files ? "git/config"
          && homeTest.files ? "yazi/yazi.toml"
        );

        home-hyprland = mkCheck "home-hyprland" (
          lib.hasInfix "[\"gaps_in\"] = 5" hyprlandLua
          && lib.hasInfix "hl.bind(\"SUPER + SPACE\"" hyprlandLua
          && lib.hasInfix "quickshell --config check" hyprlandLua
          && builtins.match ".*SECTION: settings.*SECTION: sources.*SECTION: policy.*SECTION: startup.*" hyprlandLua != null
        );

        home-rendering = mkCheck "home-rendering" (
          lib.hasInfix "alias ll 'ls -lah'" fishConfig
          && lib.hasInfix "clockFormat: \"yyyy-MM-dd HH:mm\"" policyQml
        );
      };
    };
}
