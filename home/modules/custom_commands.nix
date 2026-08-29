{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.myHome.customCommands;
in {
  options.myHome.customCommands = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the new-module Home Manager module generator.";
    };

    sourceRoot = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = "Git worktree containing the Home Manager modules and templates.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellApplication {
        name = "new-module";
        runtimeInputs = with pkgs; [
          coreutils
          git
          gnused
        ];
        text = ''
          set -eu

          usage() {
            printf 'Usage: new-module <kind> <name>\n' >&2
          }

          if [ "$#" -ne 2 ]; then
            usage
            exit 2
          fi

          kind=$1
          name=$2

          case "$kind" in
            home)
              ;;
            system)
              printf 'new-module: system modules are reserved and not implemented.\n' >&2
              exit 2
              ;;
            *)
              printf 'new-module: unknown module kind: %s\n' "$kind" >&2
              usage
              exit 2
              ;;
          esac


          if [[ ! "$name" =~ ^[a-z][a-z0-9_-]*$ ]]; then
            printf 'new-module: unsafe module name: %s\n' "$name" >&2
            exit 2
          fi

          sourceRoot=${lib.escapeShellArg cfg.sourceRoot}
          if ! repoRoot=$(git -C "$sourceRoot" rev-parse --show-toplevel 2>/dev/null); then
            printf 'new-module: source root is not a Git worktree: %s\n' "$sourceRoot" >&2
            exit 1
          fi

          targetDir="$repoRoot/home/modules"
          target="$targetDir/$name.nix"
          template=${../templates/home-module.nix}
          tmp=

          cleanup() {
            if [ -n "''${tmp:-}" ]; then
              rm -f -- "$tmp"
            fi
          }
          trap cleanup EXIT
          trap 'exit 1' HUP INT TERM

          if [ -e "$target" ] || [ -L "$target" ]; then
            printf 'new-module: refusing to overwrite existing target: %s\n' "$target" >&2
            exit 1
          fi

          if ! tmp=$(mktemp --tmpdir="$targetDir" ".new-module-$name.XXXXXX"); then
            printf 'new-module: unable to create temporary file in %s\n' "$targetDir" >&2
            exit 1
          fi

          if ! sed "s/<name>/$name/g" "$template" >"$tmp"; then
            printf 'new-module: unable to render template.\n' >&2
            exit 1
          fi

          mv --no-clobber -- "$tmp" "$target"
          if [ -e "$tmp" ]; then
            printf 'new-module: refusing to overwrite existing target: %s\n' "$target" >&2
            exit 1
          fi

          printf 'Created %s\n' "$target"
          printf 'Manual import: add ./%s.nix to home/modules/defaults.nix.\n' "$name"
        '';
      })
    ];
  };
}
