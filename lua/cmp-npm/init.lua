local Job = require "plenary.job"

local source = {}
local opts = {}

source.new = function()
  local self = setmetatable({}, { __index = source })
  return self
end

function source:is_available()
  local filename = vim.fn.expand('%:t')
  return filename == "package.json"
end

function source:get_debug_name()
  return 'npm'
end


function source:complete(params, callback)
  -- figure out if we are completing the package name or version
  local cur_line = params.context.cursor_line
  local cur_col = params.context.cursor.col
  local name, version = string.match(cur_line, '%s*"(.*)"%s*:%s*"(.*)"?')
  local _, idx_third_quote = string.find(cur_line, '.*".*".*"')
  local find_version = false
  if idx_third_quote then
    find_version = cur_col >= idx_third_quote 
  end
  if name == nil then
    name = string.match(cur_line, '%s*"(.*)"?')
  end
  if name == nil then return end
  name = name:gsub('"', "")
  if version then
    version = version:gsub('"', "")
  end
  if find_version then
    Job
      :new({
          "npm",
          "info",
          name,
          "versions",
          "--json",
          on_exit = function(job)
            local result = job:result()
            table.remove(result, 1)
            table.remove(result, table.getn(result))
            local items = {}
            for _, npm_item in ipairs(result) do
              local version = string.match(npm_item, '%s*"(.*)",?')
              table.insert(items, { label = version })
            end
            -- unfortunately, nvim-cmp uses its own sorting algorith which doesn't work for semantic versions
            -- but at least we can bring the original set in order
            table.sort(items, function(a,b)
              local a_major,a_minor,a_patch = string.match(a.label, '(%d+)%.(%d+)%.(%d+)')
              local b_major,b_minor,b_patch = string.match(b.label, '(%d+)%.(%d+)%.(%d+)')
              if a_major ~= b_major then return tonumber(a_major) > tonumber(b_major) end
              if a_minor ~= b_minor then return tonumber(a_minor) > tonumber(b_minor) end
              if a_patch ~= b_patch then return tonumber(a_patch) > tonumber(b_patch) end
            end)
            callback(items)
          end
      }):start()
  else
    Job
      :new({
          "npm",
          "search",
          "--no-description",
          "--parseable",
          name,
          on_exit = function(job)
            local result = job:result()
            local items = {}
            for _, npm_item in ipairs(result) do
              local name, _, version = string.match(npm_item, "(.*)\t(.*)\t(.*)\t")
              name = name:gsub("%s.*", "")
              local label = name .. " " .. version
              table.insert(items, { label = label, insertText = name })
            end
            callback(items)
          end
      }):start()
  end
end

function source:resolve(completion_item, callback)
  callback(completion_item)
end

function source:execute(completion_item, callback)
  callback(completion_item)
end

require('cmp').register_source("npm", source.new())

return {
  setup = function(_opts)
    -- doesn't do anything at the moment
    opts = _opts
  end
}
