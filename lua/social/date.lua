local M = {}

local named_dates = {
  day = function() return os.date("%Y-%m-%d") end,
  week = function() return os.date("%Y-%m-%d", os.time() - 7 * 24 * 60 * 60) end,
  month = function() return os.date("%Y-%m-%d", os.time() - 30 * 24 * 60 * 60) end,
  quarter = function() return os.date("%Y-%m-%d", os.time() - 90 * 24 * 60 * 60) end,
  half = function() return os.date("%Y-%m-%d", os.time() - 182 * 24 * 60 * 60) end,
  year = function() return os.date("%Y-%m-%d", os.time() - 365 * 24 * 60 * 60) end,
}

M.names = vim.tbl_keys(named_dates)

function M.parse(date)
  local is_date = date:match('%d%d%d%d%-%d%d%-%d%d') -- YYYY-MM-DD

  if is_date ~= nil then
    return is_date
  end

  local create_date = named_dates[date]
  if create_date ~= nil then
    return create_date()
  end

  error(
    'Unrecognized date - should be either YYYY-MM-DD or one of: '
    .. table.concat(M.names, ', ')
  )
end

return M
