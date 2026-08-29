local luasnip = require("luasnip")
local fmta = require("luasnip.extras.fmt").fmta

return {
  luasnip.snippet(
    "mkopt",
    fmta(
      [[
<option> = lib.mkOption {
  type = lib.types.<type>;
  default = <default>;
  description = "<description>";
};]],
      {
        option = luasnip.insert_node(1, "x"),
        type = luasnip.insert_node(2, "str"),
        default = luasnip.insert_node(3, '""'),
        description = luasnip.insert_node(4, "Describe this option."),
      }
    )
  ),
}
