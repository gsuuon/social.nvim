local M = {}

local function decode(txt)
  return vim.json.decode(txt, { luanil = { object = true } })
end

local function split_on_first_empty_line(text)
  local emptyLinePos, endOfLinePos = string.find(text, '\n\n')
  if emptyLinePos then
    return string.sub(text, 1, emptyLinePos - 1),
      string.sub(text, endOfLinePos + 1)
  else
    return text, nil -- No empty line found
  end
end

local function gh_api(headers, url, cb)
  local args = {
    'curl',
    '-sw',
    '%{stderr}%{response_code}', -- write http status to stderr
    '-L',
    '-H',
    'X-GitHub-Api-Version: 2022-11-28',
    '-i', -- include headers
  }

  for _, h in ipairs(headers) do
    table.insert(args, h)
  end

  local url_
  if url:match('^http') then
    url_ = url
  else
    url_ = 'https://api.github.com/' .. url
  end

  table.insert(args, url_)

  return vim.system(args, {
    text = true,
  }, function(done)
    if done.code ~= 0 then
      error(vim.inspect(done))
    end

    local status = done.stderr

    if not status:match('^2') then
      error(vim.inspect(done.stdout))
    end

    local out_headers, body = split_on_first_empty_line(done.stdout)

    cb({ headers = out_headers, body = body })
  end)
end

local function parse_pagination_links_from_headers(headers)
  local function parse_header_links(header_links)
    local links = {}
    for url, rel in header_links:gmatch('<(.-)>; rel="(%w+)"') do
      links[rel] = url
    end

    return links
  end

  for line in headers:gmatch('[^\r\n]+') do
    local links = line:match('Link: (.+)')
    if links then
      return parse_header_links(links)
    end
  end
  return nil
end

local function query_gh(url, cb) -- https://docs.github.com/en/rest/search/search?apiVersion=2022-11-28#search-repositories
  return gh_api(
    {
      '-H',
      'Accept: application/vnd.github+json',
    },
    url,
    function(res)
      cb({
        body = decode(res.body),
        headers = res.headers,
        links = parse_pagination_links_from_headers(res.headers),
      })
    end
  )
end

-- local function get_files(contents_url, cb)
--   return gh_api(
--     { '-H', 'Accept: application/json' },
--     contents_url:gsub('{%+path}', ''),
--     cb
--   )
-- end

-- local function get_file(contents_url, file, cb)
--   local url = contents_url:gsub('{%+path}', file)

--   return gh_api(
--     { '-H', 'Accept: application/vnd.github.raw' },
--     url,
--     cb
--   )
-- end

function M.get_user(username, cb)
  return gh_api(
    { '-H', 'Accept: application/vnd.github+json' },
    'users/' .. username,
    function(res)
      cb(decode(res.body))
    end
  )
end

local function extract_repo_item(repo_item)
  return {
    created = repo_item.created_at,
    updated = repo_item.updated_at,
    name = repo_item.name,
    full_name = repo_item.full_name,
    stars = repo_item.stargazers_count,
    url = repo_item.html_url,
    pull = {
      ssh = repo_item.ssh_url,
      clone = repo_item.clone_url,
    },
    creator = {
      name = (repo_item.owner or {}).login, -- not sure about this
      url = (repo_item.owner or {}).html_url,
    },
    description = repo_item.description,
    has_discussions = repo_item.has_discussions,
  }
end

--- @class GhQuery
--- @field created_after? string
--- @field created_before? string
--- @field updated_after? string
--- @field updated_before? string
--- @field topic? string
--- @field sort? 'stars' | 'forks' | 'help-wanted-issues' | 'updated'
--- @field per_page? number

--- @param query GhQuery
local function format_query(query) -- https://docs.github.com/en/search-github/getting-started-with-searching-on-github/understanding-the-search-syntax
  local q = ''
  local _ = '%20'

  if query.topic then
    q = q .. 'topic:' .. query.topic .. _
  end

  local created_after = query.created_after or '*'
  local created_before = query.created_before or '*'

  q = q .. 'created:' .. created_after .. '..' .. created_before .. _

  local updated_after = query.updated_after or '*'
  local updated_before = query.updated_before or '*'

  q = q .. 'pushed:' .. updated_after .. '..' .. updated_before .. _

  local params = {
    sort = query.sort,
    q = q,
    per_page = query.per_page or 20,
  }

  local params_ = {}

  for k, v in pairs(params) do
    table.insert(params_, k .. '=' .. v)
  end

  return table.concat(params_, '&')
end

--- @param query_params GhQuery
--- @param cb fun(result: { body: table, headers: table }): any
function M.query(query_params, cb)
  query_gh('search/repositories?' .. format_query(query_params), cb)
end

M.query_gh = query_gh

function M.extract_response_repos(response)
  return vim.tbl_map(extract_repo_item, response.items)
end

function M.get_readme(owner, repo, cb)
  return gh_api(
    {
      '-H',
      'Accept: application/vnd.github.raw',
    },
    string.format('https://api.github.com/repos/%s/%s/readme', owner, repo),
    function(out)
      cb(out.body)
    end
  )
end

return M
