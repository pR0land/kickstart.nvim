local M = {}

local state_file = vim.fn.stdpath 'state' .. '/background'

-- read saved background
function M.load()
  local f = io.open(state_file, 'r')
  if not f then
    return
  end

  local bg = f:read '*l'
  f:close()

  if bg == 'dark' or bg == 'light' then
    vim.o.background = bg
  end
end

-- write current background
function M.save()
  local f = io.open(state_file, 'w')
  if not f then
    return
  end

  f:write(vim.o.background)
  f:close()
end

-- toggle + persist
function M.toggle()
  vim.o.background = (vim.o.background == 'dark') and 'light' or 'dark'
  vim.cmd.colorscheme 'gruvbox'
  M.save()
end

return M
