vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    require('custom.plugins.ui.background').save()
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown', 'text' },
  callback = function()
    vim.opt_local.spell = false
  end,
})
