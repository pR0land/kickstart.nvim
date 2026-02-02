local md = require 'utils.markdown'
return {
  'pR0land/obsidian.nvim',
  version = '*', -- recommended, use latest release instead of latest commit
  lazy = false,
  ft = 'markdown',
  -- Replace the above line with this if you only want to load obsidian.nvim for markdown files in your vault:
  -- event = {
  --   -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
  --   -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/*.md"
  --   -- refer to `:h file-pattern` for more examples
  --   -- "BufReadPre path/to/my-vault/*.md",
  --   -- "BufNewFile path/to/my-vault/*.md",
  -- },
  dependencies = {
    -- Required.
    'nvim-lua/plenary.nvim',
    'hrsh7th/nvim-cmp',
    -- see below for full list of optional dependencies 👇
  },
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    -- A list of workspace names, paths, and configuration overrides.
    -- If you use the Obsidian app, the 'path' of a workspace should generally be
    -- your vault root (where the `.obsidian` folder is located).
    -- When obsidian.nvim is loaded by your plugin manager, it will automatically set
    -- the workspace to the first workspace in the list whose `path` is a parent of the
    -- current markdown file being edited.
    legacy_commands = false,
    workspaces = {
      {
        name = 'LifeSystem',
        path = '~/H_Personal/LifeSystem',
      },
    },

    note_id_func = function(title)
      if not title then
        return tostring(os.time())
      end
      return title:lower():gsub('%s+', '-'):gsub('[^a-z0-9-]', '')
    end,

    ui = {
      enable = false,
    },

    checkbox = {
      enabled = true,
      create_new = true,
      order = { ' ', 'x', '~', '!', '>' },
    },

    notes_subdir = 'Vaults/Inbox',
    new_notes_location = 'notes_subdir',
    preferred_link_style = 'markdown',

    search = {
      sort_by = 'modified',
      sort_reversed = true,
      max_lines = 1000,
    },

    callbacks = {
      -- Toggle check-boxes.
      enter_note = function(note)
        vim.keymap.set('n', '<leader>ch', '<cmd>Obsidian toggle_checkbox<cr>', {
          buffer = true,
          desc = 'Toggle checkbox',
        })
      end,
    },

    templates = {
      folder = '_resources/Templates',
      date_format = '%d-%m-%Y',
      time_format = nil,
      substitutions = {
        CurrentWEEK = md.CurrentWEEK(0),
        CurrentMONTH = md.CurrentMONTH(0),
        CurrentQUARTER = md.CurrentQUARTER(0),
      },

      ---@class obsidian.config.CustomTemplateOpts
      ---
      ---@field notes_subdir? string
      ---@field note_id_func? (fun(title: string|?, path: obsidian.Path|?): string)
      customizations = {
        WeeklyReviewTemplate = {
          notes_subdir = 'Pipelines/CycleAndReviews/Uger',
          note_id_func = function(current)
            local filename, _ = md.weekly_note(current)
            return filename
          end,
          note_title_func = function(current)
            local _, title = md.weekly_note(current)
            return title
          end,
        },

        MonthlyReviewTemplate = {
          notes_subdir = 'Pipelines/CycleAndReviews/Måneder',
          note_id_func = function(current)
            local filename, _ = md.monthly_note(current)
            return filename
          end,
          note_title_func = function(current)
            local _, title = md.monthly_note(current)
            return title
          end,
        },

        QuarterlyReviewTemplate = {
          notes_subdir = 'Pipelines/CycleAndReviews/Kvartaler',
          note_id_func = function(current)
            local filename, _ = md.quarterly_note(current)
            return filename
          end,
          note_title_func = function(current)
            local _, title = md.quarterly_note(current)
            return title
          end,
        },

        ActionItemTemplate = {
          notes_subdir = 'Pipelines/ActionItems',
          note_title_func = function(title)
            return title
          end,
          note_id_func = function(title)
            if not title then
              return tostring(os.time())
            end
            return title
          end,
        },

        AccomplishmentTemplate = {
          notes_subdir = 'Pipelines/CycleAndReviews/Accomplishments',
          note_id_func = function(title)
            if not title then
              return tostring(os.time())
            end
            return title
          end,
        },

        DisappointmentTemplate = {
          notes_subdir = 'Pipelines/CycleAndReviews/Disappointments',
          note_id_func = function(title)
            if not title then
              return tostring(os.time())
            end
            return title
          end,
        },
      },
    },

    daily_notes = {
      -- Optional, if you keep daily notes in a separate directory.j
      folder = 'Pipelines/CycleAndReviews/DailyTracking',
      -- Optional, if you want to change the date format for the ID of daily notes.
      date_format = '%d-%m-%Y',
      -- Optional, default tags to add to each new daily note created.
      default_tags = { 'daily-notes' },
      -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
      template = 'Daily.md',
    },

    completion = {
      -- Set to false to disable completion.
      nvim_cmp = true,
      -- Trigger completion at 2 chars.
      min_chars = 2,
    },

    picker = {
      -- Set your preferred picker. Can be one of 'telescope.nvim', 'fzf-lua', or 'mini.pick'.
      name = 'telescope.nvim',
      -- Optional, configure key mappings for the picker. These are the defaults.
      -- Not all pickers support all mappings.
      note_mappings = {
        -- Create a new note from your query.
        new = '<C-x>',
        -- Insert a link to the selected note.
        insert_link = '<C-l>',
      },
      tag_mappings = {
        -- Add tag(s) to current note.
        tag_note = '<C-x>',
        -- Insert a tag at the current location.
        insert_tag = '<C-l>',
      },
    },
  },

  config = function(_, opts)
    -- 1. Initialize the plugin
    require('obsidian').setup(opts)

    local tasks = require 'custom.plugins.obsidian.tasks'
    local task_scheduler = require 'custom.plugins.obsidian.task_scedule'
    -- 2. Restore the Smart Action Autocmd
    vim.api.nvim_create_autocmd('User', {
      pattern = 'ObsidianNoteEnter',
      callback = function(ev)
        pcall(vim.keymap.del, 'n', '<CR>', { buffer = true })
        vim.keymap.set('n', '<leader><CR>', require('obsidian.api').smart_action, { buffer = true })
        vim.keymap.set('n', '<leader>otp', tasks.task_pull, { desc = '[o]bsidian [t]ask [p]ull' })
        vim.keymap.set('n', '<leader>otP', tasks.push, { desc = '[o]bsidian [t]ask [P]ush' })
        vim.keymap.set('n', '<leader>ots', function()
          task_scheduler.open()
        end, { desc = '[o]bsidian [t]ask [s]chedule', noremap = true, silent = true })
      end,
    })

    vim.keymap.set('n', '<leader>ogi', function()
      require('custom.plugins.obsidian.inbox').pick_start()
    end, { desc = '[o]bsidian [g]oThrough [i]nbox' })
    vim.keymap.set('n', '<Leader>os', ':Obsidian search<CR>', { desc = '[o]bsidian [s]earch file' })
    vim.keymap.set('n', '<Leader>od', ':Obsidian today<CR>', { desc = '[o]bsidian [d]aily note' })
    vim.keymap.set('n', '<Leader>nn', ':Obsidian new<CR>', { desc = '[n]ew [n]ote in obsidian' })
    vim.keymap.set('n', '<Leader>na', function()
      md.obsidian_new_named 'ActionItemTemplate'
    end, { desc = '[n]ew [a]ction item' })
    vim.keymap.set('n', '<Leader>onw', ':Obsidian new_from_template WeeklyReviewTemplate<CR>', { desc = '[o]bsidian [n]ew [w]eekly Review' })
    vim.keymap.set('n', '<Leader>onm', ':Obsidian new_from_template MonthlyReviewTemplate<CR>', { desc = '[o]bsidian [n]ew [m]onthly Review' })
    vim.keymap.set('n', '<Leader>onq', ':Obsidian new_from_template QuarterlyReviewTemplate<CR>', { desc = '[o]bsidian [n]ew [q]uarterly Review' })
    vim.keymap.set('n', '<Leader>ont', ':Obsidian new_from_template<CR>', { desc = '[o]bsidian [n]ew from [t]emplate' })
    vim.keymap.set('n', '<Leader>ona', function()
      md.obsidian_new_named 'AccomplishmentTemplate'
    end, { desc = '[o]bsidian [n]ew [a]ccomplishment ' })
    vim.keymap.set('n', '<Leader>ond', function()
      md.obsidian_new_named 'DisappointmentTemplate'
    end, { desc = '[o]bsidian [n]ew [d]isappointment' })

    vim.keymap.set('n', '<Leader>or', function()
      local api = require 'obsidian.api'
      local util = require 'obsidian.util'
      local picker = require 'obsidian.picker'

      -- 1. Heading above cursor
      local heading = md.get_heading_above()
      if not heading then
        vim.notify('No heading found above cursor', vim.log.levels.WARN)
        return
      end

      -- 2. Heading → anchor (CRITICAL)
      local anchor = util.header_to_anchor(heading)
      if not anchor then
        vim.notify('Failed to resolve header anchor', vim.log.levels.ERROR)
        return
      end

      -- 3. Current note (same as ObsidianBacklinks)
      local note = api.current_note(0, {
        collect_anchor_links = true,
      })
      if not note then
        vim.notify('Not an Obsidian note', vim.log.levels.WARN)
        return
      end

      -- 4. Collect backlinks semantically
      local matches = note:backlinks {
        search = { sort = true },
        anchor = anchor,
      }

      if vim.tbl_isempty(matches) then
        vim.notify('No backlinks for this header', vim.log.levels.INFO)
        return
      end

      -- 5. Convert to Obsidian picker items (IMPORTANT SHAPE)
      local items = {}
      for _, match in ipairs(matches) do
        table.insert(items, {
          filename = tostring(match.path),
          lnum = match.line,
          col = match.start + 1,
          text = match.text, -- shown in Telescope
        })
      end

      -- 6. Open picker (Telescope-backed)
      picker.pick(items, {
        prompt_title = 'Backlinks → #' .. heading,
      })
    end, { desc = '[o]bsidian [r]eview for header' })
  end,
}
