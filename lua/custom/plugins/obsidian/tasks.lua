local M = {}
M.overdue_threshold = 3
local util = require 'custom.plugins.obsidian.utils'
M.task_pullers = {}
M.task_pushers = {}

local projekt_markers = {
  ['PROJEKT-TODO'] = true,
  ['PROJEKT-DONE'] = true,
}

local function collect_date_tasks(cutoff_ts)
  local dir = util.action_items_dir()
  if not dir then
    return {}
  end
  local items = {}
  for _, file in ipairs(vim.fn.glob(dir .. '/*.md', false, true)) do
    local note = util.get_existing_note(file)
    if note then
      local fm = note:frontmatter() or {}
      if fm.Status == false then
        local do_ts = util.parse_date(fm.Do_Date)
        if do_ts == nil or do_ts <= cutoff_ts then
          table.insert(items, {
            filename = vim.fn.fnamemodify(file, ':t'),
            title = fm.title or vim.fn.fnamemodify(file, ':t:r'),
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
      if a.do_ts == nil or b.do_ts == nil then
        return false
      end
      return a.do_ts < b.do_ts
    end
    return a.priority < b.priority
  end)
  return items
end

local function render_date_tasks(items, today, opts)
  opts = opts or {}
  local out = {}
  for _, it in ipairs(items) do
    local suffix = ''
    if it.do_ts then
      local overdue = util.days_between(today, it.do_ts)
      if overdue > (opts.overdue_threshold or math.huge) then
        suffix = (' — do: %s (%dd overdue)'):format(opts.date_fmt(it.do_ts), overdue)
      end
    end
    local project_prefix = it.projekt == '' and '' or 'Projekt:'
    local fields = opts.fields_func(it, project_prefix, suffix)
    table.insert(out, string.format(opts.format, unpack(fields)))
  end
  return out
end

local function render_projekt_tasks(items, completed)
  local out = {}
  for _, it in ipairs(items) do
    if completed then
      table.insert(out, string.format('- [x] (P%d) [%s](%s)', it.priority, it.title, util.urlencode(it.filename)))
    else
      table.insert(out, string.format('- [ ] (P%d) [%s](%s)', it.priority, it.title, util.urlencode(it.filename)))
    end
  end
  return out
end

local function collect_projekt_tasks(current_file, completed)
  local current_name = vim.fn.fnamemodify(current_file, ':t')
  local dir = util.action_items_dir()
  if not dir then
    return {}
  end
  local items = {}
  for _, file in ipairs(vim.fn.glob(dir .. '/*.md', false, true)) do
    local note = util.get_existing_note(file)
    if note then
      local fm = note:frontmatter() or {}
      if fm.Projekt then
        local projekt_str = tostring(fm.Projekt)
        local link_target = projekt_str:match '%((.-)%)'
        if link_target == current_name and fm.Status == completed then
          table.insert(items, {
            filename = vim.fn.fnamemodify(file, ':t'),
            title = fm.title or vim.fn.fnamemodify(file, ':t:r'),
            priority = tonumber(fm.Priority) or 99,
            projekt = fm.Projekt,
            do_ts = util.parse_date(fm.Do_Date),
            completion_date = fm.Completion_Date,
          })
        end
      end
    end
  end
  table.sort(items, function(a, b)
    if a.do_ts == b.do_ts then
      return a.priority < b.priority
    end
    if a.do_ts == nil then
      return false
    end
    if b.do_ts == nil then
      return true
    end
    return a.do_ts < b.do_ts
  end)
  return items
end

M.task_pullers['TODAY-TODO'] = function()
  local today = util.effective_today()
  local items = collect_date_tasks(today)
  return render_date_tasks(items, today, {
    overdue_threshold = M.overdue_threshold,
    date_fmt = util.fmt_date_ddmmyyyy,
    format = '- [ ] (P%d) [%s](%s) %s %s %s',
    fields_func = function(it, pref, suff)
      return { it.priority, it.title, util.urlencode(it.filename), pref, it.projekt, suff }
    end,
  })
end

M.task_pullers['TOMORROW-TODO'] = function()
  local today = util.effective_today()
  local tomorrow = today + 86400
  local items = collect_date_tasks(tomorrow)
  return render_date_tasks(items, today, {
    overdue_threshold = 0,
    date_fmt = util.fmt_date_yyyymmdd,
    format = '- (P#) [%s](%s) %s %s',
    fields_func = function(it, pref, suff)
      return { it.title, util.urlencode(it.filename), pref, it.projekt, suff }
    end,
  })
end

M.task_pullers['PROJEKT-TODO'] = function()
  local buf = vim.api.nvim_get_current_buf()
  local current_file = vim.api.nvim_buf_get_name(buf)
  local items = collect_projekt_tasks(current_file, false)
  return render_projekt_tasks(items, false)
end

M.task_pullers['PROJEKT-DONE'] = function()
  local buf = vim.api.nvim_get_current_buf()
  local current_file = vim.api.nvim_buf_get_name(buf)
  local items = collect_projekt_tasks(current_file, true)
  return render_projekt_tasks(items, true)
end

M.task_pull = function()
  local buf = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local marker = util.get_marker_block(buf, 'below_or_top', nil, cursor_line)
  if not marker then
    return
  end
  local function execute_pull(m)
    local puller = M.task_pullers[m.type]
    if not puller then
      print("DEBUG: Captured type '" .. m.type .. "' but no puller exists.")
      return
    end
    local out = puller() or {}
    util.replace_block(buf, m.start, m.finish - 1, out)
  end
  local queue = { marker }
  if projekt_markers[marker.type] then
    local partner = (marker.type == 'PROJEKT-TODO') and 'PROJEKT-DONE' or 'PROJEKT-TODO'
    local m2 = util.get_marker_block(buf, 'below_or_top', partner, 1)
    if m2 and m2.start ~= marker.start then
      table.insert(queue, m2)
    end
  end
  table.sort(queue, function(a, b)
    return a.start > b.start
  end)
  for _, m in ipairs(queue) do
    execute_pull(m)
  end
end

local function push_completed(marker, dir)
  local completed_date = util.fmt_date_yyyymmdd(util.effective_today())
  for i = marker.start + 1, marker.finish do
    local line = marker.lines[i]
    if line and line:match '^%s*%-%s*%[x%]' then
      local filename = line:match '%[.-%]%((.-)%)'
      if filename then
        util.update_frontmatter_file(dir .. '/' .. util.urldecode(filename), {
          Status = true,
          Completion_Date = completed_date,
        })
      end
    end
  end
end

local function push_priorities(marker, dir)
  local prio = 1
  local seen = {}
  for i = marker.start + 1, marker.finish do
    local filename = marker.lines[i] and marker.lines[i]:match '%[.-%]%((.-)%)'
    if filename then
      filename = util.urldecode(filename)
      if not seen[filename] then
        seen[filename] = true
        util.update_frontmatter_file(dir .. '/' .. filename, { Priority = prio })
        prio = prio + 1
      end
    end
  end
end

M.task_pushers['TODAY-TODO'] = function(marker, dir)
  push_completed(marker, dir)
  push_priorities(marker, dir)
end

M.task_pushers['TOMORROW-TODO'] = function(marker, dir)
  push_priorities(marker, dir)
end

M.task_pushers['PROJEKT-TODO'] = function(marker, dir)
  push_completed(marker, dir)
  push_priorities(marker, dir)
end

M.push = function()
  local buf = vim.api.nvim_get_current_buf()
  local marker = util.get_marker_block(buf, 'above')
  if not marker then
    return
  end
  local pusher = M.task_pushers[marker.type]
  if not pusher then
    vim.notify('No task pusher for marker: ' .. marker.type, vim.log.levels.WARN)
    return
  end
  local dir = util.action_items_dir()
  if not dir then
    return
  end
  pusher(marker, dir)
end

return M
