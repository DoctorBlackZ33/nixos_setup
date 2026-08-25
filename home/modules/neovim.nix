{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.myHome.neovim;
  neovimConfig = ../neovim/config;
  neovimInit = ../neovim/init.lua;
  lazyLock = ../neovim/lazy-lock.json;
in {
  options.myHome.neovim = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Neovim and the shared LazyVim configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      withNodeJs = true;
      extraPackages = with pkgs; [
        alejandra
        bash-language-server
        lazygit
        lua-language-server
        markdown-toc
        markdownlint-cli2
        marksman
        nodejs
        nixd
        prettier
        shellcheck
        shfmt
        statix
        stylua
        taplo
        tree-sitter
        vscode-langservers-extracted
      ];
      initLua = builtins.readFile neovimInit;
    };

    xdg.configFile."nvim" = {
      source = neovimConfig;
      recursive = true;
    };

    home.activation.neovimLazyLock = lib.hm.dag.entryAfter ["writeBoundary"] ''
      install -Dm644 ${lazyLock} ${config.xdg.dataHome}/nvim/lazy-lock.json
    '';
  };
}
