local M = {}

local function compare(a, b, opts)
  local x, y = a.value, b.value
  if opts.ignore_case then
    x, y = vim.fn.tolower(x), vim.fn.tolower(y)
  end
  if opts.numeric then
    local nx, ny =
      tonumber(x:match("^%s*([+-]?%d*%.?%d+)")), tonumber(y:match("^%s*([+-]?%d*%.?%d+)"))
    if nx and ny and nx ~= ny then
      return opts.reverse and nx > ny or not opts.reverse and nx < ny
    end
    if (nx ~= nil) ~= (ny ~= nil) then
      return opts.reverse and ny ~= nil or not opts.reverse and nx ~= nil
    end
  end
  if x == y then
    return a.index < b.index
  end
  return opts.reverse and x > y or not opts.reverse and x < y
end

local function sorted(values, opts)
  local items = {}
  for i, value in ipairs(values) do
    items[i] = { value = value, index = i }
  end
  table.sort(items, function(a, b)
    return compare(a, b, opts)
  end)
  local result = {}
  for i, item in ipairs(items) do
    result[i] = item.value
  end
  return result
end

function M.sort(lines, mode, opts)
  opts = vim.tbl_extend("force", require("editing_tools.config").options.sort, opts or {})
  if #lines > 1 or mode == "line" or mode == "block" then
    return sorted(lines, opts)
  end
  local text, values, slots = lines[1] or "", {}, {}
  local _, _, commas = require("motion_tools.scan").pairs(text)
  if #commas > 0 then
    local begin = 1
    commas[#commas + 1] = #text + 1
    for _, finish in ipairs(commas) do
      local field = text:sub(begin, finish - 1)
      local left, value, right = field:match("^(%s*)(.-)(%s*)$")
      values[#values + 1], slots[#slots + 1] = value, { left = left, right = right }
      begin = finish + 1
    end
    local result = sorted(values, opts)
    for i, value in ipairs(result) do
      result[i] = slots[i].left .. value .. slots[i].right
    end
    return { table.concat(result, ",") }
  end
  local begin = 1
  for a, value, b in text:gmatch("()(%S+)()") do
    slots[#slots + 1] = text:sub(begin, a - 1)
    values[#values + 1], begin = value, b
  end
  local result = sorted(values, opts)
  for i, value in ipairs(result) do
    result[i] = slots[i] .. value
  end
  return { table.concat(result) .. text:sub(begin) }
end

function M.multiply(lines, mode, opts)
  local times = opts.times or 1
  assert(times >= 1 and times % 1 == 0 and times <= 1000, "times must be between 1 and 1000")
  if mode == "line" then
    local result = {}
    for _ = 1, times + 1 do
      vim.list_extend(result, lines)
    end
    return result
  elseif mode == "block" then
    local result = {}
    for i, line in ipairs(lines) do
      result[i] = line:rep(times + 1)
    end
    return result
  end
  return vim.split(table.concat(lines, "\n"):rep(times + 1), "\n", { plain = true })
end

function M.evaluate(lines, _, opts)
  if opts.evaluator then
    return opts.evaluator(vim.deepcopy(lines))
  end
  local result = {}
  for i, line in ipairs(lines) do
    local prefix, expression, suffix = line:match("^(%s*)(.-)(%s*)$")
    assert(
      expression ~= "" and not expression:find("[^%d%e%E%s%.%+%-%*/%%%^%(%) ]"),
      "expected an arithmetic expression"
    )
    assert(#expression <= 4096, "expression is too long")
    local chunk, err = loadstring("return (" .. expression .. ")")
    assert(chunk, err)
    setfenv(chunk, {})
    local ok, value = pcall(chunk)
    assert(
      ok and type(value) == "number" and value == value and math.abs(value) ~= math.huge,
      "invalid or non-finite arithmetic result"
    )
    result[i] = prefix .. tostring(value) .. suffix
  end
  return result
end

function M.replace(lines, mode, opts)
  local register = opts.register or '"'
  assert(register ~= "=", "expression register is not supported")
  local content = vim.fn.getreg(register, 1, true)
  assert(#content > 0, "register is empty")
  if mode == "block" then
    if #content == 1 then
      local result = {}
      for i = 1, #lines do
        result[i] = content[1]
      end
      return result
    end
    assert(#content == #lines, "block register height must match selection")
  end
  return content
end

return M
