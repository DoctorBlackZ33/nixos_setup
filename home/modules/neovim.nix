{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.myHome.neovim;
  pluginGroups = {
    core = "plugins.core";
    coding = "plugins.coding";
    content = "plugins.content";
    workflow = "plugins.workflow";
  };
  profile = pkgs.writeText "neovim-profile.lua" ''
    return {
  ${lib.concatMapStrings (group: "  { import = \"${pluginGroups.${group}}\" },\n") cfg.pluginGroups}${lib.optionalString (cfg.hostPluginDirectory != null) "  { import = \"host_plugins\" },\n"}}
  '';
  neovimInit = builtins.readFile cfg.initFile;
  lazyLock = cfg.lockFile;
  configRoot = cfg.configRoot;
in {
  options.myHome.neovim = {
    enable = lib.mkEnableOption "the shared LazyVim Neovim configuration" // {
      default = true;
    };
    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use Neovim as the default editor.";
    };
    withNodeJs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Include Node.js support in the Neovim wrapper.";
    };
    pluginGroups = lib.mkOption {
      type = lib.types.listOf (lib.types.enum (builtins.attrNames pluginGroups));
      default = ["core"];
      description = "Shared LazyVim plugin groups to import.";
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
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
      description = "Additional packages available to Neovim and its plugins.";
    };
    extraLuaConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Lua appended to the shared Neovim init file.";
    };
    initFile = lib.mkOption {
      type = lib.types.path;
      default = ../neovim/init.lua;
      description = "The Neovim init.lua source file.";
    };
    configRoot = lib.mkOption {
      type = lib.types.path;
      default = ../neovim/config;
      description = "The shared Neovim configuration root.";
    };
    lockFile = lib.mkOption {
      type = lib.types.path;
      default = ../neovim/lazy-lock.json;
      description = "The Lazy.nvim lock file installed in Neovim's data directory.";
    };
    hostPluginDirectory = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Optional host-only Lazy plugin directory, imported separately.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = cfg.defaultEditor;
      withNodeJs = cfg.withNodeJs;
      extraPackages = cfg.extraPackages;
      initLua = neovimInit + lib.optionalString (cfg.extraLuaConfig != "") "\n" + cfg.extraLuaConfig;
    };

    xdg.configFile = {
      "nvim/colors" = {
        source = "${configRoot}/colors";
        recursive = true;
      };
      "nvim/lua/config" = {
        source = "${configRoot}/lua/config";
        recursive = true;
      };
      "nvim/lua/plugins" = {
        source = "${configRoot}/lua/plugins";
        recursive = true;
      };
      "nvim/lazyvim.json" = {
        source = "${configRoot}/lazyvim.json";
      };
      "nvim/luasnippets" = {
        source = "${configRoot}/luasnippets";
        recursive = true;
      };
      "nvim/stylua.toml" = {
        source = "${configRoot}/stylua.toml";
      };
      "nvim/lua/profile.lua" = {
        source = profile;
      };
    } // lib.optionalAttrs (cfg.hostPluginDirectory != null) {
      "nvim/lua/host_plugins" = {
        source = cfg.hostPluginDirectory;
        recursive = true;
      };
    };

    home.activation.neovimLazyLock = lib.hm.dag.entryAfter ["writeBoundary"] ''
      install -Dm644 ${lazyLock} ${config.xdg.dataHome}/nvim/lazy-lock.json
    '';
  };
}
