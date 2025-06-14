return {
  'L3MON4D3/LuaSnip',
  -- follow latest release.
  version = 'v2.*', -- Replace <CurrentMajor> by the latest released major (first number of latest release)
  -- install jsregexp (optional!).
  build = 'make install_jsregexp',
  config = function()
    require('luasnip.loaders.from_lua').lazy_load { paths = vim.fn.stdpath 'config' .. '/lua/pR0land/luasnips' }
    -- local ls = require 'luasnip'
    -- require 'luasnip' {
    --   snip_env = {
    --     s = function(...)
    --       local snip = ls.s(...)
    --       -- we can't just access the global `ls_file_snippets`, since it will be
    --       -- resolved in the environment of the scope in which it was defined.
    --       table.insert(getfenv(2).ls_file_snippets, snip)
    --     end,
    --     parse = function(...)
    --       local snip = ls.parser.parse_snippet(...)
    --       table.insert(getfenv(2).ls_file_snippets, snip)
    --     end,
    --     -- remaining definitions.
    --   },
    -- }
    -- -- Luasnips

    local ls = require 'luasnip'
    vim.keymap.set({ 'i' }, '<C-f>', function()
      ls.expand()
    end, { silent = true })
    vim.keymap.set({ 'i', 's' }, '<C-j>', function()
      ls.jump(1)
    end, { silent = true })
    vim.keymap.set({ 'i', 's' }, '<C-k>', function()
      ls.jump(-1)
    end, { silent = true })

    vim.keymap.set({ 'i', 's' }, '<C-e>', function()
      if ls.choice_active() then
        ls.change_choice(1)
      end
    end, { silent = true })
  end,
}
