local gh = require('social.gh')
local display = require('social.display')
local async = require('social.async')
local date = require('social.date')

local button_prefix = '◉ '
local link_prefix = '⇱ '

local function get_readme_stub(owner, repo, max_lines, cb)
  gh.get_readme(owner, repo, function(readme)
    local lines = {}

    for line in readme:gmatch('[^\n]+') do
      table.insert(lines, line)
      if #lines == max_lines then
        break
      end
    end

    cb(table.concat(lines, '\n'))
  end)
end

local function concat_kv(tbl, sep_kv, sep_item)
  local x = {}

  for k, v in pairs(tbl) do
    if v ~= nil then
      table.insert(x, k .. sep_kv .. v)
    end
  end

  return table.concat(x, sep_item)
end

local function concat_vals(tbl, sep)
  local x = {}
  for _, v in ipairs(tbl) do
    if v ~= nil and v ~= '' then
      table.insert(x, v)
    end
  end

  return table.concat(x, sep)
end

local function show_repos(b, repos)
  for _, repo in ipairs(repos) do
    local description = ''
    if repo.description then
      description = '\n' .. repo.description
    end

    local repo_header_hl = 'Title'
    b._mark(button_prefix .. repo.full_name, repo_header_hl, function(mark)
      local open = false
      local user_info

      mark.on_cr(function()
        if open then
          mark.text(button_prefix .. repo.full_name)
          mark.hl(repo_header_hl)
        else
          mark.text(button_prefix .. repo.full_name .. ' ..')
          mark.hl(repo_header_hl)

          if user_info == nil then
            gh.get_user(repo.creator.name, function(creator)
              local person = concat_vals({
                creator.name,
                creator.html_url,
                creator.blog,
              }, ' | ')

              local account = concat_kv({
                ['󰀎'] = creator.followers,
                [''] = creator.location,
                [''] = creator.company,
              }, ' ', '  ')

              user_info = concat_vals({
                repo.full_name,
                person,
                creator.bio,
                account,
              }, '\n')

              mark.text(user_info)
              mark.hl('Label')
            end)
          else
            mark.text(user_info)
            mark.hl('Label')
          end
        end

        open = not open
      end)
    end)

    b._mark(
      table.concat({
        link_prefix,
        '☆ ' .. repo.stars,
        repo.url,
        repo.created,
      }, ' | '),
      'Comment',
      function(mark)
        mark.on_cr(function()
          vim.ui.open(repo.url)
        end)
      end
    )

    b._text(description .. '\n')

    if repo.has_discussions then
      b._mark(link_prefix .. 'discussions', 'PmenuExtra', function(m)
        m.on_cr(function()
          vim.ui.open(repo.url .. '/discussions')
        end)
      end)
    end

    local button_hl = 'PmenuSel'
    local readme_hl = 'CursorLine'

    b._mark(button_prefix .. 'readme', button_hl, function(mark)
      local showing = false
      local readme

      mark.on_cr(function()
        mark.text('loading...')
        if showing then
          mark.text(button_prefix .. 'readme')
          mark.hl(button_hl)
          showing = false
        elseif readme then
          mark.text(readme)
          mark.hl(readme_hl, true) -- TODO this doesn't seem to work?
          showing = true
        else
          get_readme_stub(
            repo.creator.name,
            repo.name,
            15,
            vim.schedule_wrap(function(stub)
              readme = '===readme===\n' .. stub .. '\n============\n'
              mark.text(readme)
              mark.hl(readme_hl, true)
              showing = true
            end)
          )
        end
      end)
    end)

    b._text('\n')
  end
end

---@class ShowOpts
---@field topic string
---@field after_date string
---@field before_date? string
---@field page_timespan? string
---@field date_type? string
---@field buffer? table

---@param opts ShowOpts
local function query_and_show_repos(opts)
  --- ranges are inclusive on both ends so we move one of the days so our slices have different items
  local function one_day_back(date_)
    return date.format_date(date.span(date_, -date.timespans.day))
  end

  async(function(wait, resolve)
    local query_params = {
      topic = opts.topic,
      sort = 'stars',
    }

    local after_date = date.parse(opts.after_date)

    if opts.date_type == 'created' then
      query_params.created_after = after_date
      query_params.created_before = opts.before_date
        and one_day_back(opts.before_date)
    else
      query_params.updated_after = after_date
      query_params.updated_before = opts.before_date
        and one_day_back(opts.before_date)
    end

    local b = opts.buffer or display.buffer()
    local header = display.query_params(query_params)

    b.text('Checking github..\n\n' .. header)

    local response = wait(gh.query(query_params, resolve))

    local repos = gh.extract_response_repos(response.body)
    if #repos == 0 then
      b.text(header .. '\n\nNo repos found')
    else
      b.text(string.format('%s\n\n', header)) -- clear 'checking..'
    end

    if opts.page_timespan then
      vim.schedule(function()
        b._mark(
          button_prefix .. 'previous ' .. opts.page_timespan,
          'PmenuSel',
          function(mark)
            mark.on_cr(function()
              b.text('') -- clear
              query_and_show_repos(vim.tbl_deep_extend('force', opts, {
                after_date = date.format_date(
                  date.span(after_date, -date.timespans[opts.page_timespan])
                ),
                before_date = after_date,
                buffer = b,
              }))
            end)
          end
        )
        b._mark(
          button_prefix .. 'next ' .. opts.page_timespan,
          'PmenuSel',
          function(mark)
            mark.on_cr(function()
              b.text('') -- clear
              query_and_show_repos(vim.tbl_deep_extend('force', opts, {
                after_date = opts.before_date,
                before_date = date.format_date(
                  date.span(
                    opts.before_date,
                    date.timespans[opts.page_timespan]
                  )
                ),
                buffer = b,
              }))
            end)
          end
        )
        b._text('\n')
      end)
    end

    b.opt('buftype', 'nofile')
    b.hl_md()

    -- TODO we can preload the first readme? Unauthed rate limits seem very very low though
    vim.schedule(function()
      show_repos(b, repos)

      local more_response = response

      local draw_more
      draw_more = function()
        if more_response.links and more_response.links.next then
          b._mark(button_prefix .. 'more', 'DiffAdd', function(mark)
            mark.on_cr(function()
              async(function(wait_, resolve_)
                more_response =
                  wait_(gh.query_gh(more_response.links.next, resolve_))

                vim.schedule(function()
                  show_repos(b, gh.extract_response_repos(more_response.body))
                  mark.text('')

                  draw_more()
                end)
              end)
            end)
          end)
        end
      end

      draw_more()
    end)
  end)
end

local function social(args)
  local date_arg = args.fargs[1] or 'day'
  -- TODO date_arg is just switch, could be 'create'
  local topic = args.fargs[2] or 'neovim'
  -- TODO completion, document
  local date_type = args.fargs[3] or 'created'

  vim.schedule(function()
    query_and_show_repos({
      topic = topic,
      after_date = date.parse(date_arg),
      date_type = date_type,
      page_timespan = vim.tbl_contains(date.names, date_arg) and date_arg
        or nil,
    })
  end)
end

local function setup()
  vim.api.nvim_create_user_command('Social', social, {
    complete = function(cur, line)
      -- :Social w<cur>
      local args = vim.fn.split(line, ' ', true)

      if #args > 2 then
        return
      end

      if cur == '' then
        return date.names
      end

      return vim.fn.matchfuzzy(date.names, cur)
    end,
    nargs = '*',
  })
end

return {
  setup = setup,
}
