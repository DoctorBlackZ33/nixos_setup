{ config, lib, pkgs, ... }:

let
  cfg = config.myHome.nvf;
in {
  options.myHome.nvf.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the productive nvf editor configuration.";
  };

  config = lib.mkIf cfg.enable {
    programs.nvf = {
      enable = true;
      defaultEditor = false;
      settings.vim = {
        extraPackages = [ pkgs.statix ];
        # Keep the leader visible and predictable before lazy plugins load.
        globals = {
          mapleader = " ";
          maplocalleader = ",";
        };

        # Conservative editor defaults: numbered code, stable splits, persistent
        # undo, smart search, and bounded input/UI update latency.
        lineNumberMode = "number";
        searchCase = "smart";
        undoFile.enable = true;
        options = {
          cursorline = true;
          cursorlineopt = "line";
          expandtab = false;
          tabstop = 4;
          shiftwidth = 4;
          signcolumn = "yes";
          splitbelow = true;
          splitright = true;
          scrolloff = 5;
          sidescrolloff = 8;
          updatetime = 250;
          timeoutlen = 400;
          ttimeoutlen = 10;
        };

        # SSH terminals cannot safely provide a read-back clipboard. On SSH,
        # install Neovim's built-in OSC52 copy provider for both registers; the
        # provider deliberately has no paste function (host-to-remote paste is
        # not claimed). Local sessions retain the terminal's normal provider.
        clipboard = {
          enable = true;
          registers = "unnamedplus";
        };
        luaConfigRC.osc52-clipboard = ''
          if vim.env.SSH_CONNECTION ~= nil or vim.env.SSH_TTY ~= nil then
            local osc52 = require("vim.ui.clipboard.osc52")
            vim.g.clipboard = {
              name = "OSC 52",
              copy = {
                ["+"] = osc52.copy("+"),
                ["*"] = osc52.copy("*"),
              },
              -- Neovim requires matching paste closures for provider validity.
              paste = {
                ["+"] = osc52.paste("+"),
                ["*"] = osc52.paste("*"),
              },
            }
          end
        '';

        # nvim-navic documents depth_limit=0 as unlimited. Keep this separate
        # from lualine so the filename remains an absolute-path component.
        luaConfigRC.navic-depth = ''
          local navic = require("nvim-navic")
          navic.setup({
            depth_limit = 0,
          })
          local navic_attach = navic.attach
          navic.attach = function(client, bufnr)
            if client.name ~= "nil" then
              return
            end
            return navic_attach(client, bufnr)
          end
        '';

        theme = {
          enable = true;
          name = "catppuccin";
          style = "mocha";
        };

        # Noice owns the command-line UI and LSP message presentation.
        ui = {
          noice.enable = true;
          borders.enable = true;
        };

        # Lualine shows the absolute file path; nvim-navic contributes the
        # complete nested document-symbol breadcrumbs from nil.
        statusline.lualine = {
          enable = true;
          setupOpts.sections.lualine_b = [
            {
              "@1" = "filename";
              path = 1;
              symbols = {
                modified = " [+]";
                readonly = " [RO]";
              };
            }
          ];
          integrations.breadcrumbs = {
            location = "statusline";
            section = "c";
            nvim-navic.enable = true;
          };
        };

        # nixd owns every language feature except document symbols. nil is
        # restricted to symbols so nvim-navic gets a clean hierarchical tree.
        languages = {
          enableTreesitter = true;
          nix = {
            enable = true;
            treesitter.enable = true;
            lsp = {
              enable = true;
              servers = [ "nixd" "nil" ];
            };
            extraDiagnostics = {
              enable = true;
              types = [ "statix" ];
            };
          };
        };
        lsp = {
          enable = true;
          lspSignature.enable = true;
          mappings = {
            format = null;
            toggleFormatOnSave = null;
          };
          servers = {
            # Keep nil attached only for document symbols. Its on_attach hook
            # removes every other advertised provider and suppresses diagnostics.
            nil.on_attach = lib.generators.mkLuaInline ''
              function(client, _)
                if client.name ~= "nil" then
                  return
                end

                client.handlers["textDocument/publishDiagnostics"] = function() end
                client.handlers["textDocument/diagnostic"] = function() end

                local document_symbol_provider = client.server_capabilities.documentSymbolProvider
                for capability in pairs(client.server_capabilities) do
                  if capability ~= "documentSymbolProvider" and capability ~= "textDocumentSync" then
                    client.server_capabilities[capability] = nil
                  end
                end
                client.server_capabilities.documentSymbolProvider = document_symbol_provider
              end
            '';
            nixd = {
              # nixd remains authoritative for every feature except breadcrumbs and formatting.
              # Remove symbols and formatting capabilities before nvf's navic hook runs.
              on_init = lib.generators.mkLuaInline ''
                function(client, _)
                  client.server_capabilities.documentSymbolProvider = nil
                  client.server_capabilities.documentFormattingProvider = nil
                  client.server_capabilities.documentRangeFormattingProvider = nil
                end
              '';
            settings.nixd = {
              # Evaluate against this VM's pinned flake input rather than a
              # mutable channel or a second nixpkgs installation.
              nixpkgs.expr = "let flake = builtins.getFlake \"/etc/nixos\"; in import flake.inputs.nixpkgs { }";
              options = {
                nixos.expr = "(builtins.getFlake \"/etc/nixos\").nixosConfigurations.nixos-dev.options";
                home_manager.expr = "(builtins.getFlake \"/etc/nixos\").homeConfigurations.\"black@vm\".options";
              };
            };
          };
        };
        };

        autocomplete.nvim-cmp = { enable = true; sources = { nvim_lsp = "[LSP]"; luasnip = "[LuaSnip]"; buffer = "[Buffer]"; path = "[Path]"; }; };
        snippets.luasnip.enable = true;

        # Useful discovery/search surfaces for a small, focused editor setup.
        telescope = {
          enable = true;
          mappings = {
            findFiles = "<leader>ff";
            liveGrep = "<leader>fg";
            buffers = "<leader>fb";
            helpTags = "<leader>fh";
          };
        };
        filetree.neo-tree.enable = true;

        binds.whichKey = {
          enable = true;
          register = {
            "<leader>l" = "LSP / code";
            "<leader>lg" = "LSP navigation";
            "<leader>d" = "Diagnostics";
            "<leader>b" = "Buffers";
            "<leader>e" = "Explorer / UI";
            "<leader>w" = "Save";
            "<leader>q" = "Save / quit";
          };
        };

        # gd/gr/K remain the familiar LSP conventions. nvf's native leader LSP
        # maps supply code action, rename, declarations, definitions,
        # implementations, references, hover, and signature-help descriptions.
        keymaps = [
          { key = "gd"; mode = "n"; action = "<cmd>lua vim.lsp.buf.definition()<CR>"; desc = "LSP definition"; }
          { key = "gD"; mode = "n"; action = "<cmd>lua vim.lsp.buf.declaration()<CR>"; desc = "LSP declaration"; }
          { key = "gt"; mode = "n"; action = "<cmd>lua vim.lsp.buf.type_definition()<CR>"; desc = "LSP type definition"; }
          { key = "gi"; mode = "n"; action = "<cmd>lua vim.lsp.buf.implementation()<CR>"; desc = "LSP implementation"; }
          { key = "gr"; mode = "n"; action = "<cmd>lua vim.lsp.buf.references()<CR>"; desc = "LSP references"; }
          { key = "K"; mode = "n"; action = "<cmd>lua vim.lsp.buf.hover()<CR>"; desc = "LSP hover"; }
          { key = "<C-k>"; mode = "n"; action = "<cmd>lua vim.lsp.buf.signature_help()<CR>"; desc = "LSP signature help"; }
          { key = "<leader>e"; mode = "n"; action = "<cmd>Neotree toggle<CR>"; desc = "Toggle file explorer"; }
          { key = "<leader>df"; mode = "n"; action = "<cmd>lua vim.diagnostic.open_float()<CR>"; desc = "Diagnostic float"; }
          { key = "<leader>dl"; mode = "n"; action = "<cmd>lua vim.diagnostic.setloclist()<CR>"; desc = "Diagnostics list"; }
          { key = "<leader>bn"; mode = "n"; action = "<cmd>bnext<CR>"; desc = "Next buffer"; }
          { key = "<leader>bp"; mode = "n"; action = "<cmd>bprevious<CR>"; desc = "Previous buffer"; }
          { key = "<leader>bd"; mode = "n"; action = "<cmd>bdelete<CR>"; desc = "Delete buffer"; }
          { key = "<leader>w"; mode = "n"; action = "<cmd>write<CR>"; desc = "Save buffer"; }
          { key = "<leader>qq"; mode = "n"; action = "<cmd>quit<CR>"; desc = "Quit window"; }
          { key = "<leader>qa"; mode = "n"; action = "<cmd>qa<CR>"; desc = "Quit Neovim"; }
        ];

        # Nix's project style is two-space indentation, unlike the general
        # four-column/no-expandtab defaults above.
        autocmds = [
          {
            event = [ "FileType" ];
            pattern = [ "nix" ];
            command = "setlocal tabstop=2 shiftwidth=2 expandtab";
            desc = "Use two-space indentation for Nix";
          }
        ];
      };
    };
  };
}
