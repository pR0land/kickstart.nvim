local M = {}

M.cutoff_hour = 3

M.get_active_vault_root = function()
  if not Obsidian or not Obsidian.workspace then
    return nil
  end
  return tostring(Obsidian.workspace.path)
end

M.action_items_dir = function()
  local root = M.get_active_vault_root()
  if not root then
    return nil
  end
  return root .. '/Pipelines/ActionItems'
end

M.effective_today = function()
  local now = os.date '*t'
  if now.hour < M.cutoff_hour then
    now.day = now.day - 1
  end
  return os.time {
    year = now.year,
    month = now.month,
    day = now.day,
    hour = 0,
  }
end

M.urlencode = function(str)
  return str:gsub(' ', '%%20')
end

M.urldecode = function(str)
  return str:gsub('%%20', ' ')
end

M.parse_date = function(s)
  if type(s) ~= 'string' then
    return nil
  end

  local y, m, d = s:match '^(%d%d%d%d)%-(%d%d)%-(%d%d)$'
  if y then
    return os.time {
      year = tonumber(y),
      month = tonumber(m),
      day = tonumber(d),
      hour = 0,
    }
  end

  d, m, y = s:match '^(%d%d)%-(%d%d)%-(%d%d%d%d)$'
  if d then
    return os.time {
      year = tonumber(y),
      month = tonumber(m),
      day = tonumber(d),
      hour = 0,
    }
  end

  return nil
end

M.fmt_date_ddmmyyyy = function(ts)
  return os.date('%d-%m-%Y', ts)
end

M.fmt_date_yyyymmdd = function(ts)
  return os.date('%Y-%m-%d', ts)
end

M.days_between = function(a, b)
  return math.floor(os.difftime(a, b) / 86400)
end

M.get_existing_note = function(full_path)
  local ok, Note = pcall(require, 'obsidian.note')
  if not ok then
    return nil
  end
  if vim.fn.filereadable(full_path) ~= 1 then
    return nil
  end
  return Note.from_file(full_path)
end

M.get_marker_block = function(buf, start_marker, end_marker)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local start_line, end_line

  for i, l in ipairs(lines) do
    if l:find(start_marker, 1, true) then
      start_line = i
    elseif l:find(end_marker, 1, true) then
      end_line = i
      break
    end
  end

  if not start_line or not end_line or end_line <= start_line then
    return nil
  end

  return start_line, end_line - 1, lines
end

M.replace_block = function(buf, start_line, end_line, new_lines)
  if start_line > end_line then
    vim.api.nvim_buf_set_lines(buf, start_line, start_line, false, new_lines)
    return
  end
  vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, new_lines)
end

M.update_frontmatter_file = function(path, updates)
  local lines = vim.fn.readfile(path)
  if not lines or #lines == 0 then
    return
  end

  -- must start with frontmatter
  if lines[1] ~= '---' then
    return
  end

  local fm_end
  for i = 2, #lines do
    if lines[i] == '---' then
      fm_end = i
      break
    end
  end
  if not fm_end then
    return
  end

  -- parse frontmatter
  local fm = {}
  local order = {}

  for i = 2, fm_end - 1 do
    local k, v = lines[i]:match '^([%w_]+):%s*(.*)$'
    if k then
      fm[k] = v
      table.insert(order, k)
    end
  end

  -- apply updates
  for k, v in pairs(updates) do
    if type(v) == 'boolean' then
      fm[k] = v and 'true' or 'false'
    else
      fm[k] = tostring(v)
    end
    if not vim.tbl_contains(order, k) then
      table.insert(order, k)
    end
  end

  -- rebuild frontmatter
  local out = { '---' }
  for _, k in ipairs(order) do
    table.insert(out, string.format('%s: %s', k, fm[k]))
  end
  table.insert(out, '---')

  -- append body
  for i = fm_end + 1, #lines do
    table.insert(out, lines[i])
  end

  vim.fn.writefile(out, path)
end

return M
