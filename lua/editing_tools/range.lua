local M = {}
local api = vim.api

---@class EditingToolsRange
---@field start integer[] Zero-based row and byte column, inclusive.
---@field finish integer[] Zero-based row and byte column, exclusive.
---@field mode? 'char'|'line'|'block'
---@field segments? table[] Native block segments, including partial-cell padding.

function M.less(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
end

function M.equal(a, b)
  return a[1] == b[1] and a[2] == b[2]
end

function M.contains(range, pos)
  return not M.less(pos, range.start) and M.less(pos, range.finish)
end

function M.char_end(line, col)
  if col >= #line then
    return #line
  end
  local char = line:sub(col + 1):match("^[%z\1-\127\194-\244][\128-\191]*")
  return col + #(char or line:sub(col + 1, col + 1))
end

function M.validate(range, buf)
  buf = buf or 0
  assert(
    type(range) == "table" and type(range.start) == "table" and type(range.finish) == "table",
    "invalid range"
  )
  for _, pos in ipairs({ range.start, range.finish }) do
    assert(
      type(pos[1]) == "number" and type(pos[2]) == "number" and pos[1] % 1 == 0 and pos[2] % 1 == 0,
      "range positions must be integers"
    )
    local line = api.nvim_buf_get_lines(buf, pos[1], pos[1] + 1, true)[1]
    assert(line and pos[1] >= 0 and pos[2] >= 0 and pos[2] <= #line, "range is outside buffer")
    local byte = line:byte(pos[2] + 1)
    assert(not byte or byte < 128 or byte >= 192, "range splits a UTF-8 character")
  end
  assert(not M.less(range.finish, range.start), "range is reversed")
  assert(
    range.mode == nil or vim.tbl_contains({ "char", "line", "block" }, range.mode),
    "invalid range mode"
  )
  return range
end

function M.from_positions(first, last, kind, exclusive)
  local native = kind == "line" and "V" or kind == "block" and "\22" or kind
  native = native == "char" and "v" or native
  local segments =
    vim.fn.getregionpos(first, last, { type = native, exclusive = exclusive or false, eol = true })
  if #segments == 0 then
    return nil
  end
  local result = { mode = native == "V" and "line" or native == "\22" and "block" or "char" }
  result.segments = {}
  for _, pair in ipairs(segments) do
    local a, b = pair[1], pair[2]
    local row = a[2] - 1
    local line = api.nvim_buf_get_lines(0, row, row + 1, true)[1]
    local s, e = math.min(math.max(a[3] - 1, 0), #line), math.min(math.max(b[3] - 1, 0), #line)
    local endcol = M.char_end(line, e)
    local prefix = string.rep(" ", a[4])
    local suffix = ""
    if b[4] > 0 and e < #line then
      local width =
        vim.fn.strdisplaywidth(line:sub(e + 1, endcol), vim.fn.strdisplaywidth(line:sub(1, e)))
      suffix = string.rep(" ", math.max(0, width - b[4]))
    end
    result.segments[#result.segments + 1] =
      { row = row, start = s, finish = endcol, prefix = prefix, suffix = suffix }
  end
  local a, b = result.segments[1], result.segments[#result.segments]
  result.start, result.finish = { a.row, a.start }, { b.row, b.finish }
  if result.mode == "line" then
    result.start[2] = 0
    result.finish[2] = #api.nvim_buf_get_lines(0, b.row, b.row + 1, true)[1]
  elseif result.mode ~= "block" then
    result.segments = nil
  end
  if result.mode == "block" then
    result.text = vim.fn.getregion(first, last, { type = native, exclusive = exclusive or false })
  end
  return result
end

function M.operator(kind)
  return M.from_positions(vim.fn.getpos("'["), vim.fn.getpos("']"), kind, false)
end

function M.visual()
  return M.from_positions(
    vim.fn.getpos("v"),
    vim.fn.getpos("."),
    vim.fn.mode(),
    vim.o.selection == "exclusive"
  )
end

function M.get(range, buf)
  buf = buf or 0
  M.validate(range, buf)
  if range.mode == "line" then
    return api.nvim_buf_get_lines(buf, range.start[1], range.finish[1] + 1, true)
  elseif range.mode == "block" then
    return vim.deepcopy(range.text)
  end
  return api.nvim_buf_get_text(
    buf,
    range.start[1],
    range.start[2],
    range.finish[1],
    range.finish[2],
    {}
  )
end

function M.put(range, lines, buf)
  buf = buf or 0
  M.validate(range, buf)
  assert(vim.bo[buf].modifiable, "buffer is not modifiable")
  if range.mode == "line" then
    api.nvim_buf_set_lines(buf, range.start[1], range.finish[1] + 1, true, lines)
  elseif range.mode == "block" then
    assert(#lines == #range.segments, "block transform must preserve its height")
    for i = #range.segments, 1, -1 do
      local segment = range.segments[i]
      if i < #range.segments then
        vim.cmd("undojoin")
      end
      api.nvim_buf_set_text(
        buf,
        segment.row,
        segment.start,
        segment.row,
        segment.finish,
        { segment.prefix .. lines[i] .. segment.suffix }
      )
    end
  else
    api.nvim_buf_set_text(
      buf,
      range.start[1],
      range.start[2],
      range.finish[1],
      range.finish[2],
      lines
    )
  end
end

function M.select(range)
  M.validate(range)
  local start, finish = range.start, range.finish
  local is_visual = vim.fn.mode():match("^[vV\22]") ~= nil
  if is_visual then
    vim.cmd.normal({ "\27", bang = true })
  end
  api.nvim_win_set_cursor(0, { start[1] + 1, start[2] })
  vim.cmd.normal({ range.mode == "line" and "V" or "v", bang = true })
  local row, col = finish[1], finish[2]
  if range.mode ~= "line" and not M.equal(start, finish) then
    if col == 0 and row > start[1] then
      row = row - 1
      col = #api.nvim_buf_get_lines(0, row, row + 1, true)[1]
    end
    local line = api.nvim_buf_get_lines(0, row, row + 1, true)[1]
    col = vim.fn.byteidx(line, math.max(0, vim.fn.charidx(line, col) - 1))
  end
  api.nvim_win_set_cursor(0, { row + 1, math.max(0, col) })
  if vim.o.selection == "exclusive" and range.mode ~= "line" then
    vim.cmd.normal({ "l", bang = true })
  end
end

return M
