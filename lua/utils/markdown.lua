local M = {}

--- @return string|nil
-- utils/markdown.lua update (optional trim)
function M.get_heading_above()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  for i = row, 1, -1 do
    local line = vim.fn.getline(i)
    local heading = line:match '^#+%s+(.-)%s*$' -- Added lazy match and trim
    if heading then
      return heading
    end
  end
  return nil
end

function M.CurrentWEEK(offset)
  offset = offset or 1
  local t = os.time() + (offset * 7 * 24 * 60 * 60)
  return os.date('%G-W%V', t)
end

function M.CurrentMONTH(offset)
  offset = offset or 1
  local year = tonumber(os.date '%Y')
  local month = tonumber(os.date '%m') + offset
  while month > 12 do
    month = month - 12
    year = year + 1
  end
  return string.format('%04d-%02d', year, month)
end

function M.CurrentQUARTER(offset)
  offset = offset or 1
  local year = tonumber(os.date '%Y')
  local month = tonumber(os.date '%m')
  local quarter = math.floor((month - 1) / 3) + 1 + offset
  while quarter > 4 do
    quarter = quarter - 4
    year = year + 1
  end
  return string.format('%s-Q%d', year, quarter)
end

function M.weekly_note(current)
  local offset = current and 0 or 1
  local week = M.CurrentWEEK(offset)
  return string.format('Weekly_Review_%s', week), string.format('Weekly Review %s', week)
end

function M.monthly_note(current)
  local offset = current and 0 or 1
  local month = M.CurrentMONTH(offset)
  return string.format('Monthly_Review_%s', month), string.format('Monthly Review %s', month)
end

function M.quarterly_note(current)
  local offset = current and 0 or 1
  local quarter = M.CurrentQUARTER(offset)
  return string.format('Quarterly_Review_%s', quarter), string.format('Quarterly Review %s', quarter)
end

function M.review_frontmatter()
  local week = M.CurrentWEEK(0)
  local month = M.CurrentMONTH(0)
  local quarter = M.CurrentQUARTER(0)
  return {
    Uge = string.format('[%s](Weekly_Review_%s.md)', week, week),
    ['Måned'] = string.format('[%s](Monthly_Review_%s.md)', month, month),
    Kvartal = string.format('[%s](Quarterly_Review_%s.md)', quarter, quarter),
  }
end

function M.obsidian_new_named(template)
  vim.ui.input({ prompt = 'Enter title or path: ' }, function(input)
    if not input or input == '' then
      return
    end
    local cmd = string.format('Obsidian new_from_template %s %s', vim.fn.fnameescape(input), template)
    vim.cmd(cmd)
  end)
end

return M
