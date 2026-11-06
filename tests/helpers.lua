local motion_root = vim.env.EDITING_TOOLS_MOTION_DIR
  or (vim.fn.fnamemodify(vim.fn.getcwd(), ":h") .. "/motion-tools.nvim")
vim.opt.rtp:append(motion_root)
local M = { count = 0 }
M.mappings = {
  inside = "i",
  around = "a",
  inside_next = "in",
  around_next = "an",
  inside_prev = "il",
  around_prev = "al",
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
  opts = vim.tbl_deep_extend("force", { mappings = M.mappings }, vim.deepcopy(opts or {}))
  local textobjects =
    { mappings = {}, objects = opts.objects, treesitter = opts.treesitter, search = opts.search }
  for _, name in ipairs({
    "inside",
    "around",
    "inside_next",
    "around_next",
    "inside_prev",
    "around_prev",
  }) do
    textobjects.mappings[name], opts.mappings[name] = opts.mappings[name], nil
  end
  opts.objects, opts.treesitter, opts.search = nil, nil, nil
  require("motion_tools").setup({ textobjects = textobjects })
  require("editing_tools").setup(opts)
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
  local range = require("motion_tools").find_object(id, kind or "inside", opts)
  return range and table.concat(require("editing_tools.range").get(range), "\n") or nil
end
return M
