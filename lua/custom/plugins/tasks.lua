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

local function parse_date_ddmmyyyy(s)
  if type(s) ~= 'string' then
    return nil
  end
  local d, m, y = s:match '(%d%d)%-(%d%d)%-(%d%d%d%d)'
  if not d then
    return nil
  end
  return os.time {
    day = tonumber(d),
    month = tonumber(m),
    year = tonumber(y),
    hour = 0,
  }
end

local function fmt_date_ddmmyyyy(ts)
  return os.date('%d-%m-%Y', ts)
end

local function days_between(a, b)
  return math.floor(os.difftime(a, b) / 86400)
end

local function get_existing_note(full_path)
  local obsidian = get_obsidian()
  if not obsidian then
    return nil
  end
  if vim.fn.filereadable(full_path) ~= 1 then
    return nil
  end
  return obsidian.Note:new(full_path)
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
      if fm.status == 'open' and fm.Do_Date then
        local do_ts = parse_date_ddmmyyyy(fm.Do_Date)
        if do_ts and do_ts <= today then
          table.insert(items, {
            filename = vim.fn.fnamemodify(file, ':t'),
            title = vim.fn.fnamemodify(file, ':t:r'),
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

    table.insert(out, string.format('- [ ] (P%d) [%s](%s) %s%s', it.priority, it.title, it.filename, it.projekt, suffix))
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

  local completed_date = fmt_date_ddmmyyyy(effective_today())

  for i = start + 1, finish do
    local line = lines[i]
    if line and line:match '%[x%]' then
      local filename = line:match '%((.-%.md)%)'
      if filename then
        local note = get_existing_note(dir .. '/' .. filename)
        if note then
          note:update_frontmatter({
            status = 'done',
            Completion_Date = completed_date,
          }, {})
        end
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

  local tomorrow = effective_today() + 86400
  local out = {}

  for _, file in ipairs(vim.fn.glob(dir .. '/*.md', false, true)) do
    local note = get_existing_note(file)
    if note then
      local fm = note:frontmatter() or {}
      if fm.status == 'open' and fm.Do_Date then
        local do_ts = parse_date_ddmmyyyy(fm.Do_Date)
        if do_ts and do_ts <= tomorrow then
          table.insert(out, string.format('- (P?) [%s](%s) %s', vim.fn.fnamemodify(file, ':t:r'), vim.fn.fnamemodify(file, ':t'), fm.Projekt or ''))
        end
      end
    end
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
    local filename = lines[i] and lines[i]:match '%((.-%.md)%)'
    if filename and not seen[filename] then
      seen[filename] = true
      local note = get_existing_note(dir .. '/' .. filename)
      if note then
        note:update_frontmatter({ Priority = tostring(prio) }, {})
        prio = prio + 1
      end
    end
  end
end

return M
