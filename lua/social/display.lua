-- TODO this is super dirty

local function standardize_extmk_pos(mark)
  local row, col, details = mark[1], mark[2], mark[3]

  -- FIXME this isn't quite right, we only want to swap col if we've
  -- swapped row (i think?)
  return {
    start = {
      row = math.min(row, details.end_row),
      col = math.min(col, details.end_col),
    },
    stop = {
      col = math.max(col, details.end_col),
      row = math.max(row, details.end_row),
    },
  }
end

return {
  buffer = function(dont_focus)
    local buf = vim.api.nvim_create_buf(false, true)
    local ns = vim.api.nvim_create_namespace('social.nvim')

    local cr_map = {}

    local function text(content, append)
      vim.api.nvim_buf_set_lines(
        buf,
        append and -1 or 0,
        -1,
        false,
        vim.fn.split(content, '\n', true)
      )
    end

    local function mark(original, hl)
      local hl_ = hl

      vim.api.nvim_buf_set_lines(buf, -1, -1, false, { original })

      local row_ = vim.api.nvim_buf_line_count(buf) - 1
      local id = vim.api.nvim_buf_set_extmark(buf, ns, row_, 0, {
        strict = false,
        end_row = row_,
        end_col = #original + 1,
        hl_group = hl_,
      })

      local content_ = original

      local highlight = vim.schedule_wrap(function(to_end)
        local res =
          vim.api.nvim_buf_get_extmark_by_id(buf, ns, id, { details = true })

        local row, col, details = res[1], res[2], res[3]

        local pos = standardize_extmk_pos({ row, col, details })
        -- Sometimes extmark start/end get inverted, not sure how
        -- but that means e.g. start row is after end row
        -- if we try to highlight with the details we get back, nothing happens
        -- extmark apis are pretty wack atm

        vim.api.nvim_buf_set_extmark(buf, ns, pos.start.row, pos.start.col, {
          id = id,
          end_col = pos.stop.col,
          end_row = pos.stop.row,
          hl_group = hl_,
          hl_eol = to_end,
        })
      end)

      local text_ = vim.schedule_wrap(function(content)
        content_ = content

        local res =
          vim.api.nvim_buf_get_extmark_by_id(buf, ns, id, { details = true })

        local pos = standardize_extmk_pos(res)

        local lines = vim.fn.split(content, '\n', true)

        vim.api.nvim_buf_set_text(
          buf,
          pos.start.row,
          pos.start.col,
          pos.stop.row,
          pos.stop.col,
          lines
        )

        highlight()
      end)

      return {
        on_cr = function(fn)
          cr_map[id] = fn
          text_(content_)
        end,
        text = text_,
        hl = function(hl_group, to_end)
          hl_ = hl_group
          highlight(to_end)
        end,
      }
    end

    local function get_mark_at_cursor()
      local cursor = vim.api.nvim_win_get_cursor(0)

      local row = cursor[1] - 1
      local col = cursor[2]

      local marks =
        vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })

      if #marks == 0 then
        return
      end

      for _, m in ipairs(marks) do
        local pos = standardize_extmk_pos({ m[2], m[3], m[4] })

        local after_start = row > pos.start.row
          or (row == pos.start.row and col >= pos.start.col)

        local before_stop = row < pos.stop.row
          or (row == pos.stop.row and col <= pos.stop.col)

        if after_start and before_stop then
          return m[1]
        end
      end
    end

    local function focus()
      vim.api.nvim_win_set_buf(0, buf)
    end

    local function handle_cr()
      local success, id = pcall(get_mark_at_cursor)
      if not success then
        error(id)
      end

      local cr = cr_map[id]
      if cr == nil then
        return
      end
      cr()
      -- {row, 0},
      -- {row + 1, 0},
    end

    vim.api.nvim_buf_call(buf, function()
      vim.keymap.set('n', '<cr>', handle_cr, { buffer = true })
    end)

    if not dont_focus then
      focus()
    end

    return {
      _mark = function(original, hl, fn)
        local x = mark(original, hl)

        if fn ~= nil then
          fn(x)
        end
      end,
      _text = function(x)
        text(x, true)
      end,
      text = vim.schedule_wrap(text),
      focus = focus,
      opt = vim.schedule_wrap(function(name, val)
        vim.api.nvim_set_option_value(name, val, { buf = buf })
      end),
      hl_md = vim.schedule_wrap(function()
        vim.api.nvim_buf_call(buf, function()
          vim.cmd([[
      syntax include @markdown syntax/markdown.vim
      syntax region mdRegion matchgroup=Comment start="===readme===" end="============" contains=@markdown keepend
      ]])
        end)
      end),
    }
  end,
  ---@param query GhQuery
  query_params = function(query)
    local res = {}

    table.insert(res, 'topic: ' .. query.topic)

    if query.created_after and query.created_before then
      table.insert(
        res,
        'created between '
          .. query.created_after
          .. ' and '
          .. query.created_before
      )
    elseif query.created_after then
      table.insert(res, 'created after ' .. query.created_after)
    elseif query.created_before then
      table.insert(res, 'created before ' .. query.created_before)
    end

    if query.updated_after and query.updated_before then
      table.insert(
        res,
        'updated between '
          .. query.updated_after
          .. ' and '
          .. query.updated_before
      )
    elseif query.updated_after then
      table.insert(res, 'updated after ' .. query.updated_after)
    elseif query.updated_before then
      table.insert(res, 'updated before ' .. query.updated_before)
    end

    table.insert(res, 'sort by ' .. query.sort)

    return table.concat(res, '\n')
  end,
}
