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

local function social(args)
  local topic = args.fargs[1] or 'neovim'
  local date_arg = args.fargs[2] or 'today'
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

    local b = display.buf_split()
    local header = display.query_params(query_params)

    b.text('Checking github..\n\n' .. header)
    b.focus()

    local response = wait(gh.query(query_params, resolve))

    local repos = gh.extract_response_repos(response)
    if #repos == 0 then
      b.text(header .. '\n\nNo repos found')
      return
    end

    b.text(string.format('%s\n%d result(s)\n\n', header, #repos)) -- clear 'checking..'

    b.opt('buftype', 'nofile')
    b.hl_md()

    for _, repo in ipairs(repos) do
      local description = ''
      if repo.description and repo.description ~= vim.NIL then
        description = '\n' .. repo.description
      end

      vim.schedule(function()
        b._mark(repo.full_name, 'Title')

        b._mark('☆ ' .. repo.stars .. ' | ' .. repo.url , 'Comment')

        b._text(description .. '\n')

        if repo.has_discussions then
          b._mark('discussions', 'PmenuExtra', function(m)
            m.on_cr(function()
              m.text(repo.url .. '/discussions')
            end)
          end)
        end

        b._mark('readme', 'PmenuThumb', function(mark)
          mark.on_cr(function()
            mark.text('loading...')
            get_readme_stub(
              repo.creator.name,
              repo.name,
              15,
              function(stub)
                mark.text('```readme```\n' .. stub .. '\n````````````\n')
              end
            )
          end)
        end)

        b._text('\n')
      end)
    end
  end)
end

local function setup()
  vim.api.nvim_create_user_command('Social', social, {
    nargs='*'
  })
end

return {
  setup = setup
}

