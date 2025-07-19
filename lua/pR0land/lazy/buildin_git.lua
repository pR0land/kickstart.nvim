return {
  'tpope/vim-fugitive',
  config = function()
    vim.keymap.set('n', '<leader>gt', vim.cmd.Git, { desc = '[g]it [t]erminal' })

    local pR0land_buildin_git = vim.api.nvim_create_augroup('pR0land_buildin_git', {})

    local autocmd = vim.api.nvim_create_autocmd
    autocmd('BufWinEnter', {
      group = pR0land_buildin_git,
      pattern = '*',
      callback = function()
        if vim.bo.ft ~= 'fugitive' then
          return
        end

        local bufnr = vim.api.nvim_get_current_buf()
        vim.keymap.set('n', '<leader>gp', function()
          vim.cmd.Git 'push'
        end, { buffer = bufnr, remap = false, desc = ' [g]it [p]ush}' })

        -- rebase always
        vim.keymap.set('n', '<leader>gP', function()
          vim.cmd.Git { 'pull', '--rebase' }
        end, { buffer = bufnr, remap = false, desc = ' [g]it [P]ull}' })

        -- NOTE: It allows me to easily set the branch i am pushing and any tracking
        -- needed if i did not set the branch up correctly
        vim.keymap.set('n', '<leader>t', ':Git push -u origin ', { buffer = bufnr, remap = false })
      end,
    })

    vim.keymap.set('n', 'gu', '<cmd>diffget //2<CR>')
    vim.keymap.set('n', 'gh', '<cmd>diffget //3<CR>')
  end,
}
