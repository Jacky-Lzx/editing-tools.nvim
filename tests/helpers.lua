local M = { count = 0 }
function M.eq(actual, expected, message)
  M.count = M.count + 1
  assert(
    vim.deep_equal(actual, expected),
    (message or "assertion")
      .. "\nexpected: "
      .. vim.inspect(expected)
      .. "\nactual: "
      .. vim.inspect(actual)
  )
end
function M.buffer(lines, cursor)
  vim.cmd.enew({ bang = true })
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
  vim.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
  -- Separate fixture creation from edits performed by real input.
  vim.cmd("let &undolevels = &undolevels")
end
function M.keys(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "xt", false)
end
function M.lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, true)
end
function M.text(id, kind, opts)
  local range = require("editing_tools").find(id, kind or "inside", opts)
  return range and table.concat(require("editing_tools.range").get(range), "\n") or nil
end
return M
