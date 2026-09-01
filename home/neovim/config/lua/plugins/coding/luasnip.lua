return {
  {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
      local luasnip = require("luasnip")
      luasnip.setup(opts)
      require("luasnip.loaders.from_lua").lazy_load({
        paths = vim.fn.stdpath("config") .. "/luasnippets",
      })
    end,
  },
}
