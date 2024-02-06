-- NOTE :h os.time - ... The returned value is a number, whose meaning depends on your system.

local day_seconds = 24 * 60 * 60

local timespans = {
  day = day_seconds,
  week = 7 * day_seconds,
  month = 30 * day_seconds,
  quarter = 90 * day_seconds,
  half = 182 * day_seconds,
  year = 365 * day_seconds,
}

local function parse_date(date_string)
  local year, month, day = date_string:match('(%d%d%d%d)-(%d%d)-(%d%d)')

  return os.time({
    year = year,
    month = month,
    day = day,
  })
end

local function format_date(time)
  local formatted = os.date('%Y-%m-%d', time)
  ---@cast formatted string

  return formatted
end

local named_dates = {
  day = function()
    return format_date(os.time())
  end,
  week = function()
    return format_date(os.time() - timespans.week)
  end,
  month = function()
    return format_date(os.time() - timespans.month)
  end,
  quarter = function()
    return format_date(os.time() - timespans.quarter)
  end,
  half = function()
    return format_date(os.time() - timespans.half)
  end,
  year = function()
    return format_date(os.time() - timespans.year)
  end,
}

local names = vim.tbl_keys(named_dates)

local parse = function(date)
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
      .. table.concat(names, ', ')
  )
end

return {
  --- Takes either a named date or YYYY-MM-DD and returns YYYY-MM-DD
  parse = parse,
  ---@param start_time number | string
  ---@param span_seconds number
  span = function(start_time, span_seconds)
    if type(start_time) == 'number' then
      return start_time + span_seconds
    else
      return parse_date(parse(start_time)) + span_seconds
    end
  end,
  timespans = timespans,
  format_date = format_date,
  names = names,
}
