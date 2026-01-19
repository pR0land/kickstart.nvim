local M = {}
M.overdue_threshold = 3

local util = require 'custom.plugins.obsidian.utils'

M.pull_today = function()
  local buf = vim.api.nvim_get_current_buf()
  local start, finish = util.get_marker_block(buf, '<!-- TODAY-TODO:START -->', '<!-- TODAY-TODO:END -->')
  if not start then
    return
  end

  local today = util.effective_today()
  local dir = util.action_items_dir()
  if not dir then
    return
  end

  local items = {}

  for _, file in ipairs(vim.fn.glob(dir .. '/*.md', false, true)) do
    local note = util.get_existing_note(file)
    if note then
      local fm = note:frontmatter() or {}
      local display_title = fm.title or vim.fn.fnamemodify(file, ':t:r')
      if fm.Status == false and fm.Do_Date then
        local do_ts = util.parse_date(fm.Do_Date)
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
    local overdue = util.days_between(today, it.do_ts)
    local suffix = ''
    if overdue > M.overdue_threshold then
      suffix = (' — do: %s (%dd overdue)'):format(util.fmt_date_ddmmyyyy(it.do_ts), overdue)
    end

    table.insert(out, string.format('- [ ] (P%d) [%s](%s) %s%s', it.priority, it.title, util.urlencode(it.filename), it.projekt, suffix))
  end

  util.replace_block(buf, start, finish, out)
end

M.push_completed = function()
  local buf = vim.api.nvim_get_current_buf()
  local start, finish, lines = util.get_marker_block(buf, '<!-- TODAY-TODO:START -->', '<!-- TODAY-TODO:END -->')

  if not start then
    return
  end

  local dir = util.action_items_dir()
  if not dir then
    return
  end

  local completed_date = util.fmt_date_yyyymmdd(util.effective_today())

  for i = start + 1, finish do
    local line = lines[i]
    if line and line:match '^%s*%-%s*%[x%]' then
      local filename = line:match '%[.-%]%((.-)%)'
      if filename then
        filename = util.urldecode(filename)
        local full_path = dir .. '/' .. filename

        util.update_frontmatter_file(full_path, {
          Status = true,
          Completion_Date = completed_date,
        })
      end
    end
  end
end

M.pull_tomorrow = function()
  local buf = vim.api.nvim_get_current_buf()
  local start, finish = util.get_marker_block(buf, '<!-- TOMORROW-TODO:START -->', '<!-- TOMORROW-TODO:END -->')
  if not start then
    return
  end

  local dir = util.action_items_dir()
  if not dir then
    return
  end

  local today = util.effective_today()
  local tomorrow = today + 86400
  local items = {}

  for _, file in ipairs(vim.fn.glob(dir .. '/*.md', false, true)) do
    local note = util.get_existing_note(file)
    if note then
      local fm = note:frontmatter() or {}
      local display_title = fm.title or vim.fn.fnamemodify(file, ':t:r')
      if fm.Status == false and fm.Do_Date then
        local do_ts = util.parse_date(fm.Do_Date)
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
    local overdue = util.days_between(today, it.do_ts)
    local suffix = ''
    if overdue > 0 then
      suffix = (' — do: %s (%dd overdue)'):format(util.fmt_date_yyyymmdd(it.do_ts), overdue)
    end

    table.insert(out, string.format('- (P#) [%s](%s) %s%s', it.title, util.urlencode(it.filename), it.projekt, suffix))
  end

  util.replace_block(buf, start, finish, out)
end

M.push_priorities = function()
  local buf = vim.api.nvim_get_current_buf()
  local start, finish, lines = util.get_marker_block(buf, '<!-- TOMORROW-TODO:START -->', '<!-- TOMORROW-TODO:END -->')

  if not start then
    return
  end

  local dir = util.action_items_dir()
  if not dir then
    return
  end

  local prio = 1
  local seen = {}

  for i = start + 1, finish do
    local filename = lines[i] and lines[i]:match '%[.-%]%((.-)%)'
    if filename then
      filename = util.urldecode(filename)
      if not seen[filename] then
        seen[filename] = true
        local full_path = dir .. '/' .. filename

        util.update_frontmatter_file(full_path, {
          Priority = prio,
        })

        prio = prio + 1
      end
    end
  end
end

return M
