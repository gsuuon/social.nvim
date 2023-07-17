local gh = require('social.gh')
local display = require('social.display')
local async = require('social.async')
local date = require('social.date')

local function get_readme_stub(owner, repo, max_lines, cb)
  gh.get_readme(owner, repo, function(readme)
    local lines = {}

    for line in readme:gmatch('[^\n]+') do
      table.insert(lines, line)
      if #lines == max_lines then break end
    end

    cb(table.concat(lines, '\n'))
  end)
end

local function concat_kv(tbl, sep_kv, sep_item)
  local x = {}

  for k,v in pairs(tbl) do
    if v ~= nil then
      table.insert(x, k .. sep_kv .. v)
    end
  end

  return table.concat(x, sep_item)
end

local function concat_vals(tbl, sep)
  local x = {}
  for _,v in ipairs(tbl) do
    if v ~= nil and v ~= '' then
      table.insert(x, v)
    end
  end

  return table.concat(x, sep)
end

local function social(args)
  local date_arg = args.fargs[1] or 'today'
  -- TODO date_arg is just switch, could be 'create'
  local topic = args.fargs[2] or 'neovim'
  local date_type = args.fargs[3] or 'created'

  async(function(wait, resolve)
    local query_params = {
      topic = topic,
      sort = 'stars',
    }

    if date_type == 'created' then
      query_params.created_after = date(date_arg)
    else
      query_params.updated_after = date(date_arg)
    end

    local b = display.buffer()
    local header = display.query_params(query_params)

    b.text('Checking github..\n\n' .. header)

    local response = wait(gh.query(query_params, resolve))

    local repos = gh.extract_response_repos(response)
    if #repos == 0 then
      b.text(header .. '\n\nNo repos found')
      return
    end

    b.text(string.format('%s\n%d result(s)\n\n', header, #repos)) -- clear 'checking..'

    b.opt('buftype', 'nofile')
    b.hl_md()

    -- TODO we can preload the first readme? Unauthed rate limits seem very very low though
    vim.schedule(function()
      for _, repo in ipairs(repos) do
        local description = ''
        if repo.description then
          description = '\n' .. repo.description
        end

        local repo_header_hl = 'Title'
        b._mark(repo.full_name, repo_header_hl, function(mark)
          local open = false
          local user_info

          mark.on_cr(function()
            if open then
              mark.text(repo.full_name)
              mark.hl(repo_header_hl)
            else
              mark.text(repo.full_name .. ' ..')
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
                    account
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
            '☆ ' .. repo.stars,
            repo.url,
            repo.created
          }, ' | '),
          'Comment',
          function(mark)
            mark.on_cr(function()
              pcall(
                gh.get_issue_comments,
                repo.creator.name,
                repo.name,
                1,
                function(x)
                  -- TODO -next
                  -- what does this do?
                  vim.notify(vim.inspect(x))
                end
              )
            end)
          end
        )

        b._text(description .. '\n')

        if repo.has_discussions then
          b._mark('discussions', 'PmenuExtra', function(m)
            m.on_cr(function()
              m.text(repo.url .. '/discussions')
            end)
          end)
        end

        local button_hl = 'PmenuSel'
        local readme_hl = 'CursorLine'

        b._mark('readme', button_hl, function(mark)
          local showing = false
          local readme

          mark.on_cr(function()
            mark.text('loading...')
            if showing then
              mark.text('readme')
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
    end)
  end)
end

local function setup()
  vim.api.nvim_create_user_command('Social', social, {
    complete = function(cur, line, col)
    end,
    nargs = '*'
  })
end

return {
  setup = setup
}

