local M = {}
local R = require("editing_tools.range")
local Scan = require("editing_tools.scan")

local function trim(text, a, b)
  local inside = text:sub(a + 1, b)
  local leading = #(inside:match("^%s*") or "")
  local trailing = #(inside:match("%s*$") or "")
  return math.min(b, a + leading), math.max(a + leading, b - trailing)
end

local function lexical(ctx, snap)
  local text, result, id, kind = snap.text, {}, ctx.id, ctx.kind
  local function add(a, b, mode)
    result[#result + 1] = snap.range(a, b, mode)
  end
  local pairs_found, quotes = Scan.pairs(text)
  local brackets = { ["("] = "(", [")"] = "(", ["["] = "[", ["]"] = "[", ["{"] = "{", ["}"] = "{" }
  if brackets[id] or id == "b" or id == "q" or id == '"' or id == "'" or id == "`" then
    local is_quote = id == "q" or id == '"' or id == "'" or id == "`"
    for _, entry in ipairs(is_quote and quotes or pairs_found) do
      -- Quote and bracket collections are kept separate to avoid apostrophes becoming blocks.
      if (id == "b") or entry.open == (brackets[id] or id) or id == "q" then
        local a, b = entry.a, entry.b
        if kind == "inside" then
          a, b = a + 1, b - 1
          if brackets[id] or id == "b" then
            a, b = trim(text, a, b)
          end
        end
        add(a, b)
      end
    end
  elseif id == "<" or id == ">" then
    for a, b in text:gmatch("()<[^<>]*>()") do
      add(kind == "inside" and a or a - 1, kind == "inside" and b - 2 or b - 1)
    end
  elseif id == "a" or id == "u" or id == "U" then
    for _, entry in ipairs(pairs_found) do
      if id ~= "a" and entry.open == "(" then
        local pattern = id == "U" and "[%w_]+$" or "[%w_%.:]+$"
        local name = text:sub(1, entry.a):match(pattern)
        if name and not name:match("^%d") then
          add(
            kind == "inside" and entry.a + 1 or entry.a - #name,
            kind == "inside" and entry.b - 1 or entry.b
          )
        end
      elseif id == "a" then
        local boundaries = { entry.a + 1 }
        vim.list_extend(boundaries, entry.commas)
        boundaries[#boundaries + 1] = entry.b
        for i = 1, #boundaries - 1 do
          local a, b = boundaries[i], boundaries[i + 1] - 1
          if kind == "inside" then
            a, b = trim(text, a, b)
          elseif i < #boundaries - 1 then
            b = boundaries[i + 1]
            while b < entry.b - 1 and text:sub(b + 1, b + 1):match("%s") do
              b = b + 1
            end
          elseif i > 1 then
            a = a - 1
          end
          add(a, b)
        end
      end
    end
  elseif id == "d" or id == " " or id == "_" then
    local pattern = id == "d" and "%d+" or id == " " and "%s+" or "[^_%s]+"
    local at = 1
    while at <= #text do
      local a, b = text:find(pattern, at)
      if not a then
        break
      end
      if id == "_" and kind == "around" then
        if text:sub(b + 1, b + 1) == "_" then
          b = b + 1
        elseif a > 1 and text:sub(a - 1, a - 1) == "_" then
          a = a - 1
        end
      end
      add(a - 1, b)
      at = b + 1
    end
  elseif id == "e" then
    for a, word in text:gmatch("()([%w_\128-\255]+)") do
      local chars, starts = vim.fn.split(word, "\\zs"), {}
      local offset = a - 1
      for i, char in ipairs(chars) do
        starts[i], offset = offset, offset + #char
      end
      starts[#chars + 1] = offset
      local begin
      for i, char in ipairs(chars) do
        if char == "_" then
          if begin then
            add(starts[begin], starts[i])
            begin = nil
          end
        else
          local boundary = i > 1
            and (
              char:match("%u")
              and (
                chars[i - 1]:match("[%l%d]")
                or (chars[i - 1]:match("%u") and (chars[i + 1] or ""):match("%l"))
              )
            )
          if boundary and begin then
            add(starts[begin], starts[i])
            begin = nil
          end
          begin = begin or i
        end
      end
      if begin then
        add(starts[begin], starts[#chars + 1])
      end
    end
  elseif id == "t" then
    local stack = {}
    for a, slash, name, tail, close in text:gmatch("()<(/?)([%a][%w:_-]*)([^<>]-)>()") do
      if slash == "" and not tail:match("/%s*$") then
        stack[#stack + 1] = { a = a - 1, inner = close - 1, name = name }
      elseif slash == "/" and stack[#stack] and stack[#stack].name == name then
        local entry = table.remove(stack)
        add(kind == "inside" and entry.inner or entry.a, kind == "inside" and a - 1 or close - 1)
      end
    end
  end
  return result
end

local function indentation(ctx)
  local size = vim.api.nvim_buf_get_offset(ctx.buf, ctx.last)
    - vim.api.nvim_buf_get_offset(ctx.buf, ctx.first)
  if size > require("editing_tools.config").options.search.max_bytes then
    return {}
  end
  local lines = vim.api.nvim_buf_get_lines(ctx.buf, ctx.first, ctx.last, true)
  local row = ctx.pos[1] - ctx.first + 1
  if not lines[row]:find("%S") then
    return {}
  end
  local function indent(index)
    local width = 0
    for char in (lines[index]:match("^%s*") or ""):gmatch(".") do
      width = width
        + (char == "\t" and vim.bo[ctx.buf].tabstop - width % vim.bo[ctx.buf].tabstop or 1)
    end
    return width
  end
  local target = indent(row)
  local first, last = row, row
  while first > 1 and (not lines[first - 1]:find("%S") or indent(first - 1) >= target) do
    first = first - 1
  end
  while last < #lines and (not lines[last + 1]:find("%S") or indent(last + 1) >= target) do
    last = last + 1
  end
  if ctx.kind == "inside" then
    while first < last and not lines[first]:find("%S") do
      first = first + 1
    end
    while last > first and not lines[last]:find("%S") do
      last = last - 1
    end
  elseif first > 1 then
    first = first - 1
  end
  return {
    {
      start = { ctx.first + first - 1, 0 },
      finish = { ctx.first + last - 1, #lines[last] },
      mode = "line",
    },
  }
end

function M.collect(id, kind, opts)
  opts = opts or {}
  local config = require("editing_tools.config").options
  local pos = opts.pos or vim.api.nvim_win_get_cursor(0)
  if not opts.pos then
    pos = { pos[1] - 1, pos[2] }
  end
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  if buf == 0 then
    buf = vim.api.nvim_get_current_buf()
  end
  local ctx = {
    id = id,
    kind = kind,
    pos = pos,
    buf = buf,
    first = math.max(0, pos[1] - config.search.lines),
    last = math.min(vim.api.nvim_buf_line_count(buf), pos[1] + config.search.lines + 1),
  }
  local provider, candidates = config.objects[id]
  if provider == false then
    return {}
  end
  if type(provider) == "function" then
    candidates = provider(ctx) or {}
  elseif config.treesitter[id] then
    candidates = require("editing_tools.treesitter").collect(ctx, config.treesitter[id])
  elseif id == "g" then
    local last = vim.api.nvim_buf_line_count(buf) - 1
    candidates = {
      {
        start = { 0, 0 },
        finish = { last, #vim.api.nvim_buf_get_lines(buf, last, last + 1, true)[1] },
        mode = "line",
      },
    }
  elseif id == "i" then
    candidates = indentation(ctx)
  else
    local snap = Scan.snapshot(buf, pos, config.search)
    candidates = snap and lexical(ctx, snap) or {}
  end
  local result, seen = {}, {}
  for _, range in ipairs(candidates) do
    R.validate(range, buf)
    local key =
      table.concat({ range.start[1], range.start[2], range.finish[1], range.finish[2] }, ":")
    if not seen[key] then
      result[#result + 1], seen[key] = range, true
    end
  end
  return result, pos
end

function M.find(id, kind, opts)
  opts = opts or {}
  local ranges, pos = M.collect(id, kind, opts)
  local direction, count = opts.direction or "current", opts.count or 1
  assert(count >= 1 and count % 1 == 0, "count must be a positive integer")
  local contains, after, before = {}, {}, {}
  for _, range in ipairs(ranges) do
    local empty = R.equal(range.start, range.finish)
    if R.contains(range, pos) or (empty and R.equal(range.start, pos)) then
      if
        not opts.reference
        or (
            not R.equal(range.start, opts.reference.start)
            or not R.equal(range.finish, opts.reference.finish)
          )
          and not R.less(opts.reference.start, range.start)
          and not R.less(range.finish, opts.reference.finish)
      then
        contains[#contains + 1] = range
      end
    elseif R.less(pos, range.start) then
      after[#after + 1] = range
    else
      before[#before + 1] = range
    end
  end
  local function size(r)
    return (r.finish[1] - r.start[1]) * 1000000000 + r.finish[2] - r.start[2]
  end
  table.sort(contains, function(a, b)
    return size(a) < size(b)
  end)
  table.sort(after, function(a, b)
    return R.less(a.start, b.start) or R.equal(a.start, b.start) and size(a) < size(b)
  end)
  table.sort(before, function(a, b)
    return R.less(b.finish, a.finish) or R.equal(a.finish, b.finish) and size(a) < size(b)
  end)
  if direction == "next" then
    return after[count]
  elseif direction == "prev" then
    return before[count]
  end
  if #contains > 0 then
    return contains[count]
  end
  return after[count]
end

function M.select(id, kind, opts)
  local range = M.find(id, kind, opts)
  if not range then
    return false
  end
  R.select(range)
  return true
end

return M
