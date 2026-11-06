vim.opt.rtp:prepend(vim.fn.getcwd())
local editing = require("editing_tools")
local function unloaded(...)
  for _, name in ipairs({ ... }) do
    assert(not package.loaded["editing_tools." .. name], name .. " loaded before use")
  end
end

editing.setup()
editing.dispose()
editing.setup({ mappings = { multiply = "gm", align = "ga", exchange = "gx" } })
editing.command({ fargs = { "cancel" } })
unloaded("operators", "range", "objects", "scan", "treesitter", "align", "exchange", "multiedit")
vim.api.nvim_feedkeys(vim.keycode("itext<Esc>"), "xt", false)
unloaded("operators", "range", "objects", "scan", "treesitter", "align", "exchange", "multiedit")

vim.api.nvim_feedkeys("gmm", "xt", false)
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "text", "text" }))
assert(package.loaded["editing_tools.operators"] and package.loaded["editing_tools.range"])
unloaded("objects", "scan", "treesitter", "align", "exchange", "multiedit")

vim.api.nvim_feedkeys("gxx", "xt", false)
assert(require("editing_tools.exchange").pending())
unloaded("align", "multiedit")
editing.setup()
assert(not require("editing_tools.exchange").pending(), "setup must cancel a loaded exchange")

vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a=1", "long=2" })
editing.align({ start = { 0, 0 }, finish = { 1, 6 }, mode = "line" })
assert(require("editing_tools.align").is_active())
editing.setup()
assert(not require("editing_tools.align").is_active(), "setup must cancel a loaded preview")
unloaded("multiedit", "treesitter")
print(
  "First-use loading: cold setup/dispose/cancel, plain Insert, operators and session cleanup passed"
)
