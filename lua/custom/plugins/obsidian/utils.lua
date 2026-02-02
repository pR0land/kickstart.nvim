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

M.get_marker_block = function(buf, mode, type_filter, start_line)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local total = #lines
  if total == 0 then
    return nil
  end
  local cur = start_line or vim.api.nvim_win_get_cursor(0)[1]
  if cur < 1 then
    cur = 1
  end
  if cur > total then
    cur = total
  end
  local function match_start(i)
    return lines[i]:match '^<!%-%-%s*([%w%-]+):START%s*%-%->%s*$'
  end
  local function match_end(i, t)
    local escaped_t = t:gsub('%-', '%%-')
    return lines[i]:match('<!%-%-%s*' .. escaped_t .. ':END%s*%-%->')
  end
  do
    local start_i, t
    for i = cur, 1, -1 do
      local mt = match_start(i)
      if mt then
        if not type_filter or mt == type_filter then
          start_i = i
          t = mt
        end
        break
      end
      if lines[i]:match ':END%s+%-%->$' then
        break
      end
    end
    if start_i and t then
      for j = cur, total do
        if match_end(j, t) then
          return {
            start = start_i,
            finish = j,
            type = t,
            lines = lines,
          }
        end
      end
    end
  end
  local function scan_forward(from)
    for i = from, total do
      local t = match_start(i)
      print(t)
      if t and (not type_filter or t == type_filter) then
        for j = i + 1, total do
          if match_end(j, t) then
            return {
              start = i,
              finish = j,
              type = t,
              lines = lines,
            }
          end
        end
      end
    end
  end
  local function scan_backward(from)
    for i = from, 1, -1 do
      local t = match_start(i)
      if t and (not type_filter or t == type_filter) then
        for j = i + 1, total do
          if match_end(j, t) then
            return {
              start = i,
              finish = j,
              type = t,
              lines = lines,
            }
          end
        end
      end
    end
  end
  if mode == 'above' then
    return scan_backward(cur)
  end
  return scan_forward(cur) or scan_forward(1)
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
