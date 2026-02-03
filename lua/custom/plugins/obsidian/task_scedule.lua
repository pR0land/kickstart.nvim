local M = {}

-- ----------------------------
-- Namespaces
-- ----------------------------
local ns_static = vim.api.nvim_create_namespace 'obsidian_picker_static'
local ns_active = vim.api.nvim_create_namespace 'obsidian_picker_active'
local ns_sticky = vim.api.nvim_create_namespace 'obsidian_picker_sticky'

local Note = require 'obsidian.note'
local utils = require 'custom.plugins.obsidian.utils'

-- Icons
local ICON_WEEKDAY = '󰆍'
local ICON_WEEKEND = ''

local state = {
  win = nil,
  buf = nil,
  weeks = {},
  week_index = 1,
  sections = {},
  target_note = nil,
  current_week_header = nil,
  active_section = 1,
}

local function setup_highlights()
  vim.api.nvim_set_hl(0, 'ObsidianWeekHeader', { link = 'RenderMarkdownH1Bg', bold = true })
  vim.api.nvim_set_hl(0, 'ObsidianWeekdayHeader', { link = 'RenderMarkdownH2Bg', bold = true })
  vim.api.nvim_set_hl(0, 'ObsidianWeekendHeader', { link = 'RenderMarkdownH4Bg', bold = true })
  vim.api.nvim_set_hl(0, 'ObsidianDate', { link = 'Comment' })
  vim.api.nvim_set_hl(0, 'ObsidianActiveSection', { link = 'RenderMarkdownH3Bg', bold = true })
  -- New highlight group for Today's text
  vim.api.nvim_set_hl(0, 'ObsidianTodayText', { link = 'markdownUrl', bold = true })
end

-- ----------------------------
-- Helpers
-- ----------------------------
local function week_start(ts)
  local wday = tonumber(os.date('%w', ts))
  local delta = (wday == 0) and 6 or (wday - 1)
  return ts - delta * 86400
end

local function to_date_string(ts)
  return os.date('%Y-%m-%d', ts)
end

-- ----------------------------
-- Data Loading
-- ----------------------------
local function load_action_items()
  local dir = utils.action_items_dir()
  if not dir then
    return {}
  end

  local items_by_date_str = {}

  for _, path in ipairs(vim.fn.glob(dir .. '/*.md', false, true)) do
    local note = utils.get_existing_note(path) or Note.from_file(path)
    if note then
      local fm = note:frontmatter() or {}
      if fm.Status == false and fm.Do_Date and fm.Do_Date ~= '' then
        local ts = utils.parse_date(fm.Do_Date)
        if ts then
          local key = to_date_string(ts)
          items_by_date_str[key] = items_by_date_str[key] or {}
          table.insert(items_by_date_str[key], note)
        end
      end
    end
  end
  return items_by_date_str
end

local function build_forward_weeks(items_by_date_str, num_weeks)
  num_weeks = num_weeks or 52
  local today_ts = os.time { year = os.date '%Y', month = os.date '%m', day = os.date '%d' }
  local start_week = week_start(today_ts)
  local weeks, week_map = {}, {}

  for i = 0, num_weeks - 1 do
    local ws = start_week + i * 7 * 86400
    weeks[#weeks + 1] = ws
    week_map[ws] = {}

    for d = 0, 6 do
      local day_ts = ws + d * 86400
      local day_key = to_date_string(day_ts)
      week_map[ws][day_ts] = items_by_date_str[day_key] or {}
    end
  end
  return weeks, week_map
end

-- ----------------------------
-- Render week
-- ----------------------------
local function render_week(buf, week_start_ts, week_data, sections)
  vim.api.nvim_buf_clear_namespace(buf, ns_static, 0, -1)
  local today_str = os.date '%Y-%m-%d'

  local line = 1
  for i = 0, 6 do
    local ts = week_start_ts + i * 86400
    local day_str = to_date_string(ts)
    local is_today = (day_str == today_str)

    local wday = os.date('%A', ts)
    local is_weekend = os.date('%w', ts) == '0' or os.date('%w', ts) == '6'
    local icon = is_weekend and ICON_WEEKEND or ICON_WEEKDAY

    local header = string.format('%s  %s  (%s)', icon, wday, utils.fmt_date_ddmmyyyy(ts))
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { header })

    local start_line = line
    local bg_hl_group = is_weekend and 'ObsidianWeekendHeader' or 'ObsidianWeekdayHeader'

    -- Apply the background to the full line
    vim.api.nvim_buf_set_extmark(buf, ns_static, line, 0, {
      line_hl_group = bg_hl_group,
      hl_eol = true,
      priority = 10,
    })

    -- Apply text color
    if is_today then
      -- If today, color the entire header text with ObsidianTodayText
      vim.api.nvim_buf_add_highlight(buf, ns_static, 'ObsidianTodayText', line, 0, -1)
    else
      -- If not today, use the standard comment style for the date part
      local date_col = header:find '%('
      if date_col then
        vim.api.nvim_buf_add_highlight(buf, ns_static, 'ObsidianDate', line, date_col - 1, -1)
      end
    end

    line = line + 1

    local tasks = week_data[ts] or {}
    for _, note in ipairs(tasks) do
      local title = note.title or vim.fn.fnamemodify(tostring(note.path), ':t:r')
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { '  • ' .. title })
      line = line + 1
    end

    sections[#sections + 1] = { ts = ts, start = start_line, ['end'] = line - 1, notes = tasks }
  end
end

-- ----------------------------
-- Update Active Selection
-- ----------------------------
local function update_week_header()
  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local cursor_line = cursor[1] - 1

  if cursor[1] == 1 then
    vim.api.nvim_win_set_cursor(state.win, { 2, 0 })
    return
  end

  local current_s = nil
  for i, s in ipairs(state.sections) do
    if cursor_line >= s.start and cursor_line <= s['end'] then
      state.active_section = i
      current_s = s
      break
    end
  end

  vim.api.nvim_buf_clear_namespace(state.buf, ns_active, 0, -1)
  if current_s then
    for l = current_s.start, current_s['end'] do
      vim.api.nvim_buf_set_extmark(state.buf, ns_active, l, 0, {
        line_hl_group = 'ObsidianActiveSection',
        hl_eol = true,
        priority = 250,
      })
    end
  end

  if current_s then
    local ws = week_start(current_s.ts)
    if ws ~= state.current_week_header then
      state.current_week_header = ws
      local week_num = tonumber(os.date('%U', ws)) + 1
      local week_end_ts = ws + 6 * 86400

      vim.api.nvim_buf_clear_namespace(state.buf, ns_sticky, 0, -1)
      vim.api.nvim_buf_set_extmark(state.buf, ns_sticky, 0, 0, {
        virt_text = {
          {
            string.format(' Week %d (%s - %s) ', week_num, utils.fmt_date_ddmmyyyy(ws), utils.fmt_date_ddmmyyyy(week_end_ts)),
            'ObsidianWeekHeader',
          },
        },
        virt_text_pos = 'overlay',
        line_hl_group = 'ObsidianWeekHeader',
        priority = 300,
      })
    end
  end
end

-- ----------------------------
-- Navigation
-- ----------------------------
local function goto_section(i)
  if i < 1 then
    if state.week_index > 1 then
      state.week_index = state.week_index - 1
      state.sections = {}
      vim.bo[state.buf].modifiable = true
      vim.api.nvim_buf_set_lines(state.buf, 1, -1, false, {})
      render_week(state.buf, state.weeks[state.week_index], state.week_map[state.weeks[state.week_index]], state.sections)
      vim.bo[state.buf].modifiable = false
      goto_section(#state.sections)
    end
    return
  elseif i > #state.sections then
    if state.week_index < #state.weeks then
      state.week_index = state.week_index + 1
      state.sections = {}
      vim.bo[state.buf].modifiable = true
      vim.api.nvim_buf_set_lines(state.buf, 1, -1, false, {})
      render_week(state.buf, state.weeks[state.week_index], state.week_map[state.weeks[state.week_index]], state.sections)
      vim.bo[state.buf].modifiable = false
      goto_section(1)
    end
    return
  end
  state.active_section = i
  vim.api.nvim_win_set_cursor(state.win, { state.sections[state.active_section].start + 1, 0 })
  update_week_header()
end

local function next_section()
  goto_section(state.active_section + 1)
end
local function prev_section()
  goto_section(state.active_section - 1)
end

local function choose_date()
  local s = state.sections[state.active_section]
  if not s or not state.target_note then
    return
  end

  local date_val = utils.fmt_date_yyyymmdd(s.ts)
  local note_path = tostring(state.target_note.path)

  utils.update_frontmatter_file(note_path, { Do_Date = date_val })

  vim.api.nvim_win_close(state.win, true)
  vim.cmd 'checktime'
  vim.notify('Scheduled: ' .. date_val, vim.log.levels.INFO)
end

-- ----------------------------
-- Main
-- ----------------------------
function M.open()
  setup_highlights()
  state.current_week_header = nil

  local buf_name = vim.api.nvim_buf_get_name(0)
  if buf_name == '' then
    return
  end

  local note = utils.get_existing_note(buf_name) or Note.from_file(buf_name)
  if not note then
    return
  end
  state.target_note = note

  local items_by_date_str = load_action_items()
  local weeks, week_map = build_forward_weeks(items_by_date_str, 52)
  state.weeks = weeks
  state.week_map = week_map

  local today_ts = os.time { year = os.date '%Y', month = os.date '%m', day = os.date '%d' }
  state.week_index = 1
  for i, ws in ipairs(weeks) do
    if today_ts >= ws and today_ts <= ws + 6 * 86400 then
      state.week_index = i
      break
    end
  end

  state.sections = {}
  state.buf = vim.api.nvim_create_buf(false, true)

  local win_width = math.max(60, vim.o.columns - 40)
  local win_height = math.max(15, vim.o.lines - 16)
  local row = math.floor((vim.o.lines - win_height) / 2)
  local col = math.floor((vim.o.columns - win_width) / 2)

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = 'editor',
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
  })

  vim.bo[state.buf].bufhidden = 'wipe'
  vim.bo[state.buf].modifiable = true
  render_week(state.buf, state.weeks[state.week_index], state.week_map[state.weeks[state.week_index]], state.sections)
  vim.bo[state.buf].modifiable = false

  goto_section(1)

  local map = function(lhs, fn)
    vim.keymap.set('n', lhs, fn, { buffer = state.buf, silent = true })
  end
  map('j', next_section)
  map('k', prev_section)
  map('<C-n>', next_section)
  map('<C-p>', prev_section)
  map('<C-d>', function()
    goto_section(#state.sections + 1)
  end)
  map('<C-u>', function()
    goto_section(0)
  end)
  map('<CR>', choose_date)
  map('<C-y>', choose_date)
  map('q', function()
    vim.api.nvim_win_close(state.win, true)
  end)
  map('gg', function()
    goto_section(1)
  end)

  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = state.buf,
    callback = update_week_header,
  })
end

return M
