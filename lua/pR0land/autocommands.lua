vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    require('ui.background').save()
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'text' },
  callback = function()
    vim.opt_local.spell = false
  end,
})
-- require 'pR0land.plugin_configs.harpoon_config'
