{ ... }:
{
  flake.modules.homeManager = {
    homeMod-fish = ./fish.nix;
    homeMod-gh = ./gh.nix;
    homeMod-git = ./git.nix;
    homeMod-home-manager = ./home-manager.nix;
    homeMod-lazygit = ./lazygit.nix;
    homeMod-shell-aliases = ./shell-aliases.nix;
    homeMod-yazi = ./yazi.nix;
    homeMod-zoxide = ./zoxide.nix;
  };
}
