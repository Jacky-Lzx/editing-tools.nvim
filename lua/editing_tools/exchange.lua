local M = {}
local api = vim.api
local R = require("editing_tools.range")
local ns = api.nvim_create_namespace("editing_tools.exchange")
local pending

function M.cancel()
  if pending and api.nvim_buf_is_valid(pending.buf) then
    pcall(api.nvim_buf_del_extmark, pending.buf, ns, pending.mark)
  end
  pending = nil
end

function M.pending()
  return pending ~= nil
end

local function current_range()
  if
    not pending
    or not api.nvim_buf_is_valid(pending.buf)
    or not api.nvim_buf_is_loaded(pending.buf)
  then
    return nil
  end
  local mark = api.nvim_buf_get_extmark_by_id(pending.buf, ns, pending.mark, { details = true })
  if #mark == 0 or mark[3].invalid then
    return nil
  end
  return {
    start = { mark[1], mark[2] },
    finish = { mark[3].end_row, mark[3].end_col },
    mode = pending.mode,
  }
end

function M.apply(range, buf)
  buf = buf or api.nvim_get_current_buf()
  if buf == 0 then
    buf = api.nvim_get_current_buf()
  end
  R.validate(range, buf)
  assert(
    range.mode ~= "block",
    "exchange accepts character and line ranges; block exchange is unsupported"
  )
  assert(vim.bo[buf].modifiable, "buffer is not modifiable")
  if not pending then
    api.nvim_set_hl(0, "EditingToolsExchange", { link = "IncSearch", default = true })
    local mark = api.nvim_buf_set_extmark(buf, ns, range.start[1], range.start[2], {
      end_row = range.finish[1],
      end_col = range.finish[2],
      right_gravity = true,
      end_right_gravity = false,
      hl_group = "EditingToolsExchange",
      hl_eol = range.mode == "line",
    })
    pending = { buf = buf, mark = mark, text = R.get(range, buf), mode = range.mode }
    return false
  end
  local first, source = current_range(), pending
  M.cancel()
  assert(first, "first exchange range no longer exists")
  assert(vim.bo[source.buf].modifiable, "first buffer is not modifiable")
  assert(
    first.mode == range.mode or (first.mode or "char") == (range.mode or "char"),
    "exchange ranges must use the same selection mode"
  )
  assert(
    vim.deep_equal(R.get(first, source.buf), source.text),
    "first exchange range changed; select it again"
  )
  local second_text = R.get(range, buf)
  if source.buf == buf then
    local a, b = first, range
    local atext, btext = source.text, second_text
    if R.less(b.start, a.start) then
      a, b, atext, btext = b, a, btext, atext
    end
    local separate = a.mode == "line" and a.finish[1] < b.start[1]
      or a.mode ~= "line" and not R.less(b.start, a.finish)
    assert(separate, "exchange ranges overlap")
    R.put(b, atext, buf)
    vim.cmd("undojoin")
    R.put(a, btext, buf)
  else
    -- Each buffer has its own native undo history.
    R.put(range, source.text, buf)
    api.nvim_buf_call(source.buf, function()
      R.put(first, second_text, source.buf)
    end)
  end
  return true
end

return M
