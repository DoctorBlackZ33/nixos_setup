{ config, ... }:

let
  modules = config.flake.modules.homeManager;
in {
  flake.modules.homeManager = {
    module-custom-commands = ./custom_commands.nix;
    module-desktop-tools = ./desktop-tools.nix;
    module-direnv = ./direnv.nix;
    module-fish = ./fish.nix;
    module-fuzzel = ./fuzzel.nix;
    module-gh = ./gh.nix;
    module-git = ./git.nix;
    module-home-manager = ./home-manager.nix;
    module-hyprland = ./hyprland.nix;
    module-lazygit = ./lazygit.nix;
    module-mako = ./mako.nix;
    module-neovim = ./neovim.nix;
    module-quickshell = ./quickshell.nix;
    module-yazi = ./yazi.nix;
    module-zoxide = ./zoxide.nix;

    module-set = {
      imports = [
        modules.module-custom-commands
        modules.module-desktop-tools
        modules.module-direnv
        modules.module-fish
        modules.module-fuzzel
        modules.module-gh
        modules.module-git
        modules.module-home-manager
        modules.module-hyprland
        modules.module-lazygit
        modules.module-mako
        modules.module-neovim
        modules.module-quickshell
        modules.module-yazi
        modules.module-zoxide
      ];
    };
  };
}
