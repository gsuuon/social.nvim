local named_dates = {
  today = function() return os.date("%Y-%m-%d") end,
  week = function() return os.date("%Y-%m-%d", os.time() - 7 * 24 * 60 * 60) end,
  month = function() return os.date("%Y-%m-%d", os.time() - 30 * 24 * 60 * 60) end,
  quarter = function() return os.date("%Y-%m-%d", os.time() - 90 * 24 * 60 * 60) end,
  half = function() return os.date("%Y-%m-%d", os.time() - 182 * 24 * 60 * 60) end,
  year = function() return os.date("%Y-%m-%d", os.time() - 365 * 24 * 60 * 60) end,
}

local function parse(date)
  local is_date = date:match('%d%d%d%d%-%d%d%-%d%d') -- YYYY-MM-DD

  if is_date ~= nil then
    return is_date
  end

  local create_date = named_dates[date]
  if create_date ~= nil then
    return create_date()
  end

  error("Unrecognized date - use either YYYY-MM-DD or 'today', 'week', 'month'")
end

return parse
