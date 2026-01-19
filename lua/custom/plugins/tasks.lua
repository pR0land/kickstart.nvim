local M = {}
M.cutoff_hour = 3
M.overdue_threshold = 3

local function get_obsidian()
  local ok, obsidian = pcall(require, 'obsidian')
  if not ok then
    vim.notify('tasks.lua: obsidian.nvim not found', vim.log.levels.ERROR)
    return nil
  end
  return obsidian
end

local function get_vault_root()
  if not Obsidian or not Obsidian.workspace then
    return nil
  end
  return tostring(Obsidian.workspace.path)
end

local function action_items_dir()
  local root = get_vault_root()
  if not root then
    return nil
  end
  return root .. '/Pipelines/ActionItems'
end

local function effective_today()
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

local function urlencode(str)
  return str:gsub(' ', '%%20')
end

local function urldecode(str)
  return str:gsub('%%20', ' ')
end

local function parse_date(s)
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

local function fmt_date_ddmmyyyy(ts)
  return os.date('%d-%m-%Y', ts)
end

local function fmt_date_yyyymmdd(ts)
  return os.date('%Y-%m-%d', ts)
end

local function days_between(a, b)
  return math.floor(os.difftime(a, b) / 86400)
end

local function get_existing_note(full_path)
  local ok, Note = pcall(require, 'obsidian.note')
  if not ok then
    return nil
  end
  if vim.fn.filereadable(full_path) ~= 1 then
    return nil
  end
  return Note.from_file(full_path)
end

local function get_marker_block(buf, start_marker, end_marker)
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

local function replace_block(buf, start_line, end_line, new_lines)
  if start_line > end_line then
    vim.api.nvim_buf_set_lines(buf, start_line, start_line, false, new_lines)
    return
  end
  vim.api.nvim_buf_set_lines(buf, start_line, end_line, false, new_lines)
end

local function update_frontmatter_file(path, updates)
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

M.pull_today = function()
  local buf = vim.api.nvim_get_current_buf()
  local start, finish = get_marker_block(buf, '<!-- TODAY-TODO:START -->', '<!-- TODAY-TODO:END -->')
  if not start then
    return
  end

  local today = effective_today()
  local dir = action_items_dir()
  if not dir then
    return
  end

  local items = {}

  for _, file in ipairs(vim.fn.glob(dir .. '/*.md', false, true)) do
    local note = get_existing_note(file)
    if note then
      local fm = note:frontmatter() or {}
      local display_title = fm.title or vim.fn.fnamemodify(file, ':t:r')
      if fm.Status == false and fm.Do_Date then
        local do_ts = parse_date(fm.Do_Date)
        if do_ts and do_ts <= today then
          table.insert(items, {
            filename = vim.fn.fnamemodify(file, ':t'),
            title = display_title,
            priority = tonumber(fm.Priority) or 99,
            projekt = fm.Projekt or '',
            do_ts = do_ts,
          })
        end
      end
    end
  end
  table.sort(items, function(a, b)
    if a.priority == b.priority then
      return a.do_ts < b.do_ts
    end
    return a.priority < b.priority
  end)

  local out = {}
  for _, it in ipairs(items) do
    local overdue = days_between(today, it.do_ts)
    local suffix = ''
    if overdue > M.overdue_threshold then
      suffix = (' — do: %s (%dd overdue)'):format(fmt_date_ddmmyyyy(it.do_ts), overdue)
    end

    table.insert(out, string.format('- [ ] (P%d) [%s](%s) %s%s', it.priority, it.title, urlencode(it.filename), it.projekt, suffix))
  end

  replace_block(buf, start, finish, out)
end

M.push_completed = function()
  local buf = vim.api.nvim_get_current_buf()
  local start, finish, lines = get_marker_block(buf, '<!-- TODAY-TODO:START -->', '<!-- TODAY-TODO:END -->')

  if not start then
    return
  end

  local dir = action_items_dir()
  if not dir then
    return
  end

  local completed_date = fmt_date_yyyymmdd(effective_today())

  for i = start + 1, finish do
    local line = lines[i]
    if line and line:match '^%s*%-%s*%[x%]' then
      local filename = line:match '%[.-%]%((.-)%)'
      if filename then
        filename = urldecode(filename)
        local full_path = dir .. '/' .. filename

        update_frontmatter_file(full_path, {
          Status = true,
          Completion_Date = completed_date,
        })
      end
    end
  end
end

M.pull_tomorrow = function()
  local buf = vim.api.nvim_get_current_buf()
  local start, finish = get_marker_block(buf, '<!-- TOMORROW-TODO:START -->', '<!-- TOMORROW-TODO:END -->')
  if not start then
    return
  end

  local dir = action_items_dir()
  if not dir then
    return
  end

  local today = effective_today()
  local tomorrow = today + 86400
  local items = {}

  for _, file in ipairs(vim.fn.glob(dir .. '/*.md', false, true)) do
    local note = get_existing_note(file)
    if note then
      local fm = note:frontmatter() or {}
      local display_title = fm.title or vim.fn.fnamemodify(file, ':t:r')
      if fm.Status == false and fm.Do_Date then
        local do_ts = parse_date(fm.Do_Date)
        if do_ts and do_ts <= tomorrow then
          table.insert(items, {
            filename = vim.fn.fnamemodify(file, ':t'),
            title = display_title,
            priority = tonumber(fm.Priority) or 99,
            projekt = fm.Projekt or '',
            do_ts = do_ts,
          })
        end
      end
    end
  end

  table.sort(items, function(a, b)
    if a.priority == b.priority then
      return a.do_ts < b.do_ts
    end
    return a.priority < b.priority
  end)

  local out = {}
  for _, it in ipairs(items) do
    local overdue = days_between(today, it.do_ts)
    local suffix = ''
    if overdue > 0 then
      suffix = (' — do: %s (%dd overdue)'):format(fmt_date_yyyymmdd(it.do_ts), overdue)
    end

    table.insert(out, string.format('- (P#) [%s](%s) %s%s', it.title, urlencode(it.filename), it.projekt, suffix))
  end

  replace_block(buf, start, finish, out)
end

M.push_priorities = function()
  local buf = vim.api.nvim_get_current_buf()
  local start, finish, lines = get_marker_block(buf, '<!-- TOMORROW-TODO:START -->', '<!-- TOMORROW-TODO:END -->')

  if not start then
    return
  end

  local dir = action_items_dir()
  if not dir then
    return
  end

  local prio = 1
  local seen = {}

  for i = start + 1, finish do
    local filename = lines[i] and lines[i]:match '%[.-%]%((.-)%)'
    if filename then
      filename = urldecode(filename)
      if not seen[filename] then
        seen[filename] = true
        local full_path = dir .. '/' .. filename

        update_frontmatter_file(full_path, {
          Priority = prio,
        })

        prio = prio + 1
      end
    end
  end
end

return M
