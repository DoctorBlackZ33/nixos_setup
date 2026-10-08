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

        # Resolve inputs and options from the file's flake, never the generation
        # that built this editor. Each root gets its own nixd evaluation workers.
        # Default targets are the first sorted output names; :NixLspTarget changes
        # one target for the current project for this Neovim session.
        # <leader>lt opens that selector. Option evaluation reads saved files;
        # projects without deployment outputs get only their own upstream schemas.
        # lib.types.* completion details can still be "?" upstream; gd resolves
        # their implementation, whereas package and module-option metadata has docs.
        # https://github.com/nix-community/nixd/blob/main/nixd/docs/configuration.md
        # https://github.com/hercules-ci/flake-parts/blob/main/lib.nix
        luaConfigRC.nix-project = lib.hm.dag.entryBefore [ "lsp-servers" ] ''
          NvfNix = { targets = {} }
          local function quote(value)
            return vim.json.encode(value):gsub("%$" .. "{", "\\" .. "$" .. "{")
          end

          function NvfNix.root(bufnr, on_dir)
            on_dir(vim.fs.root(bufnr, "flake.nix")
              or vim.fs.root(bufnr, ".git")
              or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
          end

          -- Dropbar's documented source API, using exact Nix binding nodes.
          -- Its generic prefix matcher also matches binding_set and repeats names.
          -- https://github.com/Bekaboo/dropbar.nvim#making-a-new-source
          NvfNix.breadcrumbs = {
            get_symbols = function(buf, win, cursor)
              local tree = vim.treesitter.get_parser(buf, "nix"):parse()[1]
              local row, col = cursor[1] - 1, cursor[2]
              local node = tree:root():named_descendant_for_range(row, col, row, col)
              local symbols = {}
              while node do
                if node:type() == "binding" then
                  local path = node:field("attrpath")[1]
                  if path then
                    local sr, sc, er, ec = node:range()
                    local pr, pc = path:range()
                    table.insert(symbols, 1, require("dropbar.bar").dropbar_symbol_t:new({
                      name = vim.treesitter.get_node_text(path, buf),
                      icon = "",
                      buf = buf,
                      win = win,
                      range = {
                        start = { line = sr, character = sc },
                        ["end"] = { line = er, character = ec },
                      },
                      on_click = function(symbol)
                        vim.api.nvim_set_current_win(symbol.win)
                        vim.api.nvim_win_set_cursor(symbol.win, { pr + 1, pc })
                      end,
                    }))
                  end
                end
                node = node:parent()
              end
              return symbols
            end,
          }

          function NvfNix.settings(root)
            if not root or not vim.uv.fs_stat(root .. "/flake.nix") then
              return {}
            end
            local targets = NvfNix.targets[root] or {}
            local prefix = "let flake = builtins.getFlake " .. quote(root) .. "; "
              .. "pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; }; "
            local function target(kind)
              return targets[kind] and quote(targets[kind]) or "builtins.head names"
            end
            local parts = prefix .. [[
              parts = flake.inputs.flake-parts;
              evaluated = (import (]] .. quote(root .. "/flake.nix") .. [[)).outputs
                (flake.inputs // {
                  self = flake;
                  flake-parts = parts // {
                    lib = parts.lib // { mkFlake = parts.lib.evalFlakeModule; };
                  };
                });
              in if flake.inputs ? flake-parts then
            ]]
            return {
              nixpkgs = { expr = prefix .. "in pkgs" },
              options = {
                nixos = { expr = prefix .. [[
                  configurations = flake.nixosConfigurations or {};
                  names = builtins.attrNames configurations;
                  in (if names == [] then flake.inputs.nixpkgs.lib.nixosSystem {
                    system = builtins.currentSystem;
                    modules = [];
                  } else builtins.getAttr (]] .. target("nixos") .. [[) configurations).options
                ]] },
                home_manager = { expr = prefix .. [[
                  configurations = flake.homeConfigurations or {};
                  names = builtins.attrNames configurations;
                  in if flake.inputs ? home-manager then
                    (if names == [] then flake.inputs.home-manager.lib.homeManagerConfiguration {
                      inherit pkgs;
                      # Base-schema evaluation needs identity and a state version;
                      # this does not activate or invent a project configuration.
                      modules = [{
                        home = {
                          username = builtins.getEnv "USER";
                          homeDirectory = builtins.getEnv "HOME";
                          stateVersion = "26.05";
                        };
                      }];
                    } else builtins.getAttr (]] .. target("home_manager") .. [[) configurations).options
                  else {}
                ]] },
                -- evalFlakeModule exposes the original module's options without
                -- adding debug outputs or duplicating its imports in this config.
                flake_parts = { expr = parts .. "evaluated.options else {}" },
                flake_parts_per_system = {
                  expr = parts .. "(evaluated.config.perSystem builtins.currentSystem).debug.options else {}",
                },
              },
            }
          end

          vim.api.nvim_create_user_command("NixLspTarget", function()
            local client = vim.lsp.get_clients({ bufnr = 0, name = "nixd" })[1]
            if not client then
              return vim.notify("No nixd client attached to this buffer", vim.log.levels.WARN)
            end
            local root = client.config.root_dir
            local expr = "let f = builtins.getFlake " .. quote(root) .. "; in { "
              .. "nixos = builtins.attrNames (f.nixosConfigurations or {}); "
              .. "home_manager = builtins.attrNames (f.homeConfigurations or {}); }"
            vim.system({ "nix", "eval", "--impure", "--json", "--expr", expr }, { text = true }, function(result)
              vim.schedule(function()
                if result.code ~= 0 then
                  return vim.notify(result.stderr, vim.log.levels.ERROR)
                end
                local outputs = vim.json.decode(result.stdout)
                local choices = {}
                for _, kind in ipairs({ "nixos", "home_manager" }) do
                  for _, name in ipairs(outputs[kind]) do
                    choices[#choices + 1] = { kind = kind, name = name }
                  end
                end
                if #choices == 0 then
                  return vim.notify("No configuration outputs in " .. root
                    .. "; using this project's upstream base option schemas", vim.log.levels.INFO)
                end
                vim.ui.select(choices, {
                  prompt = "Nix LSP target: " .. root,
                  format_item = function(item) return item.kind .. ": " .. item.name end,
                }, function(item)
                  if not item or client:is_stopped() then return end
                  NvfNix.targets[root] = NvfNix.targets[root] or {}
                  NvfNix.targets[root][item.kind] = item.name
                  client.settings.nixd = NvfNix.settings(root)
                  client:notify("workspace/didChangeConfiguration", { settings = client.settings })
                  vim.notify("Nix LSP " .. root .. " — " .. item.kind .. ": " .. item.name)
                end)
              end)
            end)
          end, { desc = "Select this project's NixOS or Home Manager option schema" })
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
          # nixd's dotted-attribute symbol ranges omit enclosing namespaces.
          # Use the syntax tree for Nix breadcrumbs, without altering LSP data.
          dropbar-nvim = {
            enable = true;
            setupOpts = {
              bar = {
                enable = lib.generators.mkLuaInline ''
                  function(buf) return vim.bo[buf].filetype == "nix" end
                '';
                sources = lib.generators.mkLuaInline ''
                  function()
                    local sources = require("dropbar.sources")
                    return { sources.path, NvfNix.breadcrumbs }
                  end
                '';
              };
            };
          };
        };

        # Keep the filename in the statusline; syntax breadcrumbs live in the winbar.
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
        };

        # nixd owns completion, navigation, refactoring, diagnostics and symbols.
        languages = {
          enableTreesitter = true;
          nix = {
            enable = true;
            treesitter.enable = true;
            lsp = {
              enable = true;
              servers = [ "nixd" ];
            };
            extraDiagnostics = {
              enable = true;
              types = [ "statix" ];
            };
          };
        };
        lsp = {
          enable = true;
          # nixd does not advertise signatureHelp, declaration, typeDefinition,
          # implementation or workspaceSymbol. Do not offer nonfunctional actions.
          lspSignature.enable = false;
          mappings = {
            format = null;
            toggleFormatOnSave = null;
            goToDeclaration = null;
            goToType = null;
            listImplementations = null;
            signatureHelp = null;
            listWorkspaceSymbols = null;
            addWorkspaceFolder = null;
            removeWorkspaceFolder = null;
          };
          servers = {
            # nvf's cmp integration supplies completion-only capabilities.
            # Preserve native markdown, symbol hierarchy and the rest of LSP.
            "*".capabilities = lib.mkForce (lib.generators.mkLuaInline ''
              vim.tbl_deep_extend("force", vim.lsp.protocol.make_client_capabilities(), capabilities)
            '');
            nixd = {
              root_dir = lib.generators.mkLuaInline "NvfNix.root";
              on_init = lib.generators.mkLuaInline ''
                function(client)
                  client.settings.nixd = NvfNix.settings(client.config.root_dir)
                  client:notify("workspace/didChangeConfiguration", { settings = client.settings })
                end
              '';
            };
          };
        };

        autocomplete.nvim-cmp = {
          enable = true;
          sources = {
            nvim_lsp = "[LSP]";
            luasnip = "[LuaSnip]";
            buffer = "[Buffer]";
            path = "[Path]";
          };
          # Buffer words are a fallback, not a substitute for evaluated symbols.
          setupOpts.sources = lib.mkForce [
            { name = "nvim_lsp"; group_index = 1; priority = 1000; }
            { name = "path"; group_index = 1; priority = 750; }
            { name = "luasnip"; group_index = 1; priority = 500; }
            { name = "buffer"; group_index = 2; keyword_length = 3; }
          ];
        };
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

        # gd/gr/K plus nvf's native leader maps expose supported Nix LSP methods.
        # Rename is for lexical bindings, not arbitrary evaluated module attributes.
        keymaps = [
          { key = "gd"; mode = "n"; action = "<cmd>lua vim.lsp.buf.definition()<CR>"; desc = "LSP definition"; }
          { key = "gr"; mode = "n"; action = "<cmd>lua vim.lsp.buf.references()<CR>"; desc = "LSP references"; }
          { key = "K"; mode = "n"; action = "<cmd>lua vim.lsp.buf.hover()<CR>"; desc = "LSP hover"; }
          { key = "<leader>lt"; mode = "n"; action = "<cmd>NixLspTarget<CR>"; desc = "Select project Nix configuration"; }
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
