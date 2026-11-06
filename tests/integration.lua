local H = require("tests.helpers")
local parent = vim.fn.fnamemodify(vim.fn.getcwd(), ":h")
if
  vim.fn.isdirectory(parent .. "/pairs.nvim") == 0
  or vim.fn.isdirectory(parent .. "/motion-tools.nvim") == 0
then
  print("integration: skipped (sibling pairs.nvim and motion-tools.nvim checkouts unavailable)")
  return
end
vim.opt.runtimepath:append(parent .. "/pairs.nvim")
vim.opt.runtimepath:append(parent .. "/motion-tools.nvim")
require("pairs").setup({ surround = { enabled = true } })
dofile("tests/helpers.lua").setup()
require("motion_tools").setup({ mappings = true })

H.buffer({ "" })
H.keys("i(x<Esc>")
H.eq(H.lines(), { "(x)" }, "pair insertion remains owned by pairs.nvim")
H.buffer({ "word" })
H.keys("saiw)")
H.eq(H.lines(), { "(word)" }, "surround mapping remains active")
H.buffer({ "(one) (two)" }, { 1, 1 })
H.keys("cibvalue<Esc>$h.")
H.eq(H.lines(), { "(value) (value)" }, "editing objects and repeat coexist with pairing")
H.buffer({ "c b a", "f e d" })
H.keys("gs$j0.")
H.eq(H.lines(), { "a b c", "d e f" })
H.eq(
  vim.fn.maparg("]i", "n", false, true).desc,
  "[Motion] next more indent",
  "motion navigation retains ownership"
)
H.eq(vim.fn.maparg("sr", "n", false, true).desc ~= nil, true, "surround retains ownership")
H.buffer({ "a=1", "long=2" })
H.keys("2gaa<CR>")
H.eq(H.lines(), { "a    = 1", "long = 2" }, "alignment coexists with sibling plugins")
print("integration: " .. H.count .. " assertions passed with actual sibling checkouts")
