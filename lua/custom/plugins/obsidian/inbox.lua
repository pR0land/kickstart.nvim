local M = {}

local utils = require 'custom.plugins.obsidian.utils'
local wk = require 'which-key'
local action_state = require 'telescope.actions.state'
local actions = require 'telescope.actions'
local inbox_path = vim.fn.fnamemodify(utils.get_active_vault_root() .. '/Vaults/Inbox', ':p')
M.is_inbox_active = false
M.augroup = vim.api.nvim_create_augroup('InboxMode', { clear = true })

local function real_path(path)
  return vim.loop.fs_realpath(path) or vim.fn.fnamemodify(path, ':p')
end

local function get_inbox_prefix()
  local qf = vim.fn.getqflist { idx = 0, size = 0 }
  if qf.size == 0 then
    return ''
  end
  return string.format('[Inbox %d/%d] ', qf.idx, qf.size)
end

function M.refresh_statusline()
  if not M.is_inbox_active then
    return
  end
  local base = vim.opt.statusline:get()
  if not base:find '%[Inbox' then
    vim.opt_local.statusline = get_inbox_prefix() .. base
  else
    vim.opt_local.statusline = get_inbox_prefix() .. base:gsub('^%[Inbox %d+/%d+%] ', '')
  end
end

function M.sync_queue()
  local qf = vim.fn.getqflist()
  if #qf == 0 then
    return false, false
  end
  local new_qf = {}
  local current_idx = vim.fn.getqflist({ idx = 0 }).idx
  local current_item_removed = false
  for i, item in ipairs(qf) do
    local path = item.bufnr > 0 and vim.api.nvim_buf_get_name(item.bufnr) or item.filename
    if vim.fn.filereadable(path) == 1 then
      table.insert(new_qf, item)
    else
      if i == current_idx then
        current_item_removed = true
      end
    end
  end
  if #new_qf < #qf then
    vim.fn.setqflist(new_qf, 'r')
    local new_idx = math.max(1, math.min(current_idx, #new_qf))
    if #new_qf > 0 then
      vim.cmd('silent ' .. new_idx .. 'cc')
    end
    return true, current_item_removed
  end
  return false, false
end

function M.apply_buffer_config()
  if not M.is_inbox_active then
    return
  end
  local opts = { buffer = true, silent = true }
  vim.keymap.set('n', '<leader>in', M.next, vim.tbl_extend('force', opts, { desc = '[n]ext' }))
  vim.keymap.set('n', '<leader>ip', M.prev, vim.tbl_extend('force', opts, { desc = '[p]revious' }))
  vim.keymap.set('n', '<leader>iq', M.exit, vim.tbl_extend('force', opts, { desc = '[q]uit' }))
  if wk then
    wk.add { { '<leader>i', group = '[i]nbox', buffer = true } }
  end
  M.refresh_statusline()
end

function M.enable_inbox_mode()
  M.is_inbox_active = true
  vim.api.nvim_create_autocmd('BufEnter', {
    group = M.augroup,
    pattern = '*',
    callback = function()
      if M.is_inbox_active then
        M.apply_buffer_config()
      end
    end,
  })
  M.apply_buffer_config()
end

function M.next()
  local _, removed = M.sync_queue()
  if removed then
    return
  end
  local qf = vim.fn.getqflist { size = 0, idx = 0 }
  if qf.size == 0 then
    return M.exit()
  end
  if qf.idx >= qf.size then
    vim.cmd 'silent cfirst'
  else
    vim.cmd 'silent cnext'
  end
  M.refresh_statusline()
end

function M.prev()
  M.sync_queue()
  local qf = vim.fn.getqflist { size = 0, idx = 0 }
  if qf.size == 0 then
    return M.exit()
  end
  if qf.idx <= 1 then
    vim.cmd 'silent clast'
  else
    vim.cmd 'silent cprev'
  end
  M.refresh_statusline()
end

function M.exit()
  M.is_inbox_active = false
  vim.api.nvim_clear_autocmds { group = M.augroup }
  vim.opt_local.statusline = nil
  vim.cmd 'cclose'
  vim.notify 'Inbox Mode Exited'
end

function M.pick_start()
  local inbox_files = vim.fn.globpath(inbox_path, '**/*.md', false, true)
  if #inbox_files == 0 then
    return vim.notify 'Inbox empty 🎉'
  end
  table.sort(inbox_files, function(a, b)
    return a > b
  end)
  require('telescope.builtin').find_files {
    prompt_title = 'Inbox',
    cwd = inbox_path,
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        local selected_path = real_path(inbox_path .. '/' .. selection.value:gsub('^/', ''))
        local qfitems = {}
        local start_idx = 1
        for i, f in ipairs(inbox_files) do
          local p = real_path(f)
          table.insert(qfitems, { filename = p })
          if p == selected_path or vim.fn.fnamemodify(p, ':t') == vim.fn.fnamemodify(selected_path, ':t') then
            start_idx = i
          end
        end
        vim.fn.setqflist(qfitems, 'r')
        M.enable_inbox_mode()
        vim.cmd('silent ' .. start_idx .. 'cc')
      end)
      return true
    end,
  }
end

return M
