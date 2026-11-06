local M = vim.tbl_extend("force", {}, require("motion_tools.range"))
local api = vim.api

function M.operator(kind)
  return M.from_positions(vim.fn.getpos("'["), vim.fn.getpos("']"), kind, false)
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
  if buf ~= 0 and buf ~= api.nvim_get_current_buf() then
    return api.nvim_buf_call(buf, function()
      return M.put(range, lines, buf)
    end)
  end
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

return M
