local M = { count = 0 }
M.mappings = {
  inside = "i",
  around = "a",
  inside_next = "in",
  around_next = "an",
  inside_prev = "il",
  around_prev = "al",
  goto_start = "g[",
  goto_end = "g]",
  replace = "cr",
  exchange = "gx",
  multiply = "gm",
  sort = "gs",
  evaluate = "g=",
  align = "ga",
  insert_visual = "mI",
  append_visual = "mA",
}
function M.setup(opts)
  require("editing_tools").setup(
    vim.tbl_deep_extend("force", { mappings = M.mappings }, opts or {})
  )
end
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
