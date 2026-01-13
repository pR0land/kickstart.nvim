-- Make sure all the keymaps and options are imported from their files
require 'pR0land.keymaps'
require 'pR0land.options'
require 'pR0land.lazy_init'

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'text' },
  callback = function()
    vim.opt_local.spell = false
  end,
})
-- require 'pR0land.plugin_configs.harpoon_config'
