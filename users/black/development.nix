# Development tools, on workstations only.
{ lib, pkgs, facts, ... }:
{
  config = lib.mkIf (facts.kind == "workstation") {
    packages = [ pkgs.lazygit ];

    direnv.enable = true;
    gh.enable = true;
  };
}
