return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "nix") then
        table.insert(opts.ensure_installed, "nix")
      end
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.nil_ls = false
      for _, server in ipairs({ "bashls", "jsonls", "lua_ls", "marksman", "nixd", "taplo" }) do
        opts.servers[server] = vim.tbl_deep_extend("force", opts.servers[server] or {}, {
          mason = false,
        })
      end
      opts.servers.nixd = {
        mason = false,
        settings = {
          nixd = {
            nixpkgs = {
              expr = "import (builtins.getFlake (builtins.toString ./.)).inputs.nixpkgs {}",
            },
            formatting = {
              command = { "alejandra" },
            },
            options = {
              nixos = {
                expr = "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.nixos-dev.options",
              },
              home_manager = {
                expr = "(builtins.getFlake (builtins.toString ./.)).homeConfigurations.black.options",
              },
            },
          },
        },
      }
    end,
  },
  {
    "mason-org/mason.nvim",
    config = function(_, opts)
      -- The selected LazyVim extras request CLI tools from Mason. They are
      -- provided by the Home Manager Neovim wrapper instead, so Mason does
      -- not download a second, unpinned copy.
      opts.ensure_installed = {}
      require("mason").setup(opts)
    end,
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.nix = { "alejandra" }
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.nix = { "statix" }
    end,
  },
}
