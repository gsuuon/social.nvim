local M = {}

local function gh_api(headers, url, cb)
  local args =
  {
    'curl',
    '-L',
    '-H',
    'X-GitHub-Api-Version: 2022-11-28'
  }

  for _, h in ipairs(headers) do
    table.insert(args, h)
  end

  table.insert(args, url)

  return vim.system(args, {
    text = true
  }, function(done)
    if done.code ~= 0 then
      error(vim.inspect(done))
    end

    cb(done.stdout)
  end)
end

local function query_gh(query, cb)
  return gh_api({
      '-H',
      'Accept: application/vnd.github+json',
    },
    'https://api.github.com/search/repositories?' .. query,
    function(res)
      cb(vim.json.decode(res))
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
      clone = repo_item.clone_url
    },
    creator = {
      name = (repo_item.owner or {}).login, -- not sure about this
      url = (repo_item.owner or {}).html_url
    },
    description = repo_item.description,
    has_discussions = repo_item.has_discussions
  }
end

--- @class GhQuery
--- @field created_after? string
--- @field updated_after? string
--- @field topic? string
--- @field sort? 'stars' | 'forks' | 'help-wanted-issues' | 'updated'

--- @param query GhQuery
local function format_query(query)
  local q = ''
  local _ = '%20'

  if query.topic then
    q = q .. 'topic:' .. query.topic .. _
  end

  if query.created_after then
    q = q .. 'created:>=' .. query.created_after .. _
  end

  if query.updated_after then
    q = q .. 'pushed:>=' .. query.updated_after .. _
  end

  local params = {
    sort = query.sort,
    q = q
  }

  local params_ = {}

  for k, v in pairs(params) do
    table.insert(params_, k .. '=' .. v)
  end

  return table.concat(params_, '&')
end

--- @param query_params GhQuery
function M.query(query_params, cb)
  query_gh(format_query(query_params), cb)
end

function M.extract_response_repos(response)
  return vim.tbl_map(extract_repo_item, response.items)
end

function M.get_readme(owner, repo, cb)
  return gh_api(
    {
      '-H',
      'Accept: application/vnd.github.raw'
    },
    string.format('https://api.github.com/repos/%s/%s/readme', owner, repo),
    cb
  )
end


return M
