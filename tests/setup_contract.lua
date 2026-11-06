vim.opt.rtp:prepend(vim.fn.getcwd())
local editing = require("editing_tools")
local config = require("editing_tools.config")
local original = function() end
vim.keymap.set("n", "<F6>", original, { desc = "personal" })
local opts = { mappings = { multiply = "<F6>" }, sort = { numeric = true } }
local copy = vim.deepcopy(opts)
editing.setup(opts)
opts.sort.numeric = false
assert(config.options.sort.numeric == copy.sort.numeric)
local mapping = vim.fn.maparg("<F6>", "n", false, true)
local configured = vim.deepcopy(config.options)
assert(not pcall(editing.setup, { mappings = { multiply = {} } }))
assert(vim.deep_equal(configured, config.options))
assert(vim.deep_equal(mapping, vim.fn.maparg("<F6>", "n", false, true)))
assert(not pcall(editing.setup, false))
editing.setup(copy)
editing.dispose()
assert(vim.fn.maparg("<F6>", "n", false, true).callback == original)
editing.dispose()
editing.setup(copy)
vim.keymap.set("n", "<F6>", "USER", { desc = "replacement" })
editing.dispose()
assert(vim.fn.maparg("<F6>", "n") == "USER")
assert(vim.deep_equal(config.options, config.defaults))
-- A later user change to options remains owned by the user, even with the same rhs.
editing.setup({ mappings = { multiply = "<F7>" } })
vim.keymap.set("n", "<F7>", "<Plug>(EditingTools-multiply)", { desc = "user description" })
editing.dispose()
assert(vim.fn.maparg("<F7>", "n", false, true).desc == "user description")
-- Global restoration must work beneath a local override, including leader keys.
vim.g.mapleader = ","
vim.keymap.set("n", "<Leader>z", "GLOBAL", { desc = "global original" })
vim.keymap.set("n", "<Leader>z", "LOCAL", { buffer = true })
editing.setup({ mappings = { multiply = "<Leader>z" } })
assert(vim.fn.maparg(",z", "n") == "LOCAL")
vim.g.mapleader = ";"
editing.dispose()
assert(vim.fn.maparg(",z", "n") == "LOCAL")
vim.keymap.del("n", ",z", { buffer = true })
assert(vim.fn.maparg(",z", "n") == "GLOBAL")
print(
  "Editing lifecycle: validation, isolated options, repeated setup and mapping ownership/restoration passed"
)
