vim.opt.rtp:prepend(vim.fn.getcwd())
require("tests.helpers")
local tools = require("editing_tools")
local before = {}
for _, mode in ipairs({ "n", "x", "o", "i" }) do
  before[mode] = vim.api.nvim_get_keymap(mode)
end
tools.setup()
for _, edge in ipairs({ "start", "end" }) do
  assert(vim.fn.maparg("<Plug>(EditingTools-goto_" .. edge .. ")", "n") == "")
end
for mode, mappings in pairs(before) do
  local actual = vim.tbl_filter(function(item)
    return not item.lhs:find("<Plug>(EditingTools", 1, true)
  end, vim.api.nvim_get_keymap(mode))
  assert(vim.deep_equal(mappings, actual), "setup changed user keys in " .. mode)
end
require("motion_tools").setup()
vim.keymap.set("o", "iz", "<Plug>(MotionTools-inside)")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "(example)" })
vim.api.nvim_win_set_cursor(0, { 1, 2 })
vim.api.nvim_feedkeys(vim.keycode("yizb"), "xt", false)
assert(vim.fn.getreg('"') == "example")
vim.keymap.set("n", "<F6>", "<Plug>(EditingTools-multiply-line)")
vim.api.nvim_feedkeys(vim.keycode("<F6>"), "xt", false)
assert(vim.api.nvim_buf_line_count(0) == 2)
tools.setup()
assert(vim.fn.maparg("iz", "o") == "<Plug>(MotionTools-inside)")
print("Unmapped defaults and user-owned remapped text objects/operators passed")
