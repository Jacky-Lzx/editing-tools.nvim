local H = require("tests.helpers")
local E = require("editing_tools")
local R = require("editing_tools.range")
dofile("tests/helpers.lua").setup()
vim.notify = function() end
H.buffer({ "a123" }, { 1, 1 })
vim.o.selection = "exclusive"
H.keys("did")
H.eq(H.lines(), { "a" }, "exclusive text object ending at EOL")
vim.o.selection = "inclusive"
H.buffer({ "abc", "def", "ghi" })
dofile("tests/helpers.lua").setup({
  objects = {
    z = function()
      return { { start = { 0, 1 }, finish = { 2, 0 } } }
    end,
  },
})
H.keys("diz")
H.eq(H.lines(), { "aghi" }, "exclusive finish at next row column zero includes newline")
dofile("tests/helpers.lua").setup()
H.buffer({ "() ()" }, { 1, 1 })
H.keys("ci(X<Esc>$h.")
H.eq(H.lines(), { "(X) (X)" }, "repeat empty native change")
for _, delimiters in ipairs({ "[]", "{}", "(  )", "[  ]", "{  }" }) do
  H.buffer({ delimiters }, { 1, 1 })
  H.keys("cibX<Esc>")
  H.eq(
    H.lines(),
    { delimiters:sub(1, 1) .. "X" .. delimiters:sub(-1) },
    "generic empty bracket change"
  )
end
H.buffer({ '""' }, { 1, 0 })
H.keys("ciqX<Esc>")
H.eq(H.lines(), { '"X"' }, "generic empty quote change")
H.buffer({ "(a) () ()" }, { 1, 1 })
H.keys("cibX<Esc>")
vim.api.nvim_win_set_cursor(0, { 1, 5 })
H.keys(".")
H.eq(H.lines(), { "(X) (X) ()" }, "repeat nonempty change into empty object")
vim.api.nvim_win_set_cursor(0, { 1, 9 })
H.keys(".")
H.eq(H.lines(), { "(X) (X) (X)" }, "retain change motion after empty repeat")
H.buffer({ "()" }, { 1, 1 })
vim.fn.setreg("a", "named")
vim.fn.setreg("-", "small")
vim.fn.setreg("1", "numbered")
vim.fn.setreg('"', "unnamed")
local registers = {}
for _, name in ipairs({ "a", "-", "1", '"' }) do
  registers[name] = vim.fn.getreginfo(name)
end
H.keys('"acibX<Esc>')
H.eq(H.lines(), { "(X)" })
for name, info in pairs(registers) do
  H.eq(vim.fn.getreginfo(name), info, "empty change preserves " .. name)
end
H.keys("u")
H.eq(H.lines(), { "()" }, "empty change undoes in one step")
H.keys("<C-r>")
H.eq(H.lines(), { "(X)" }, "empty change redo has no placeholder")
H.buffer({ "keep me" })
H.keys("gmiz")
H.eq(H.lines(), { "keep me" }, "missing object cannot invoke operator")
dofile("tests/helpers.lua").setup({
  objects = {
    w = function()
      return { { start = { 0, 0 }, finish = { 0, 2 } } }
    end,
  },
})
H.buffer({ "abcd" })
H.keys("diw")
H.eq(H.lines(), { "cd" }, "custom provider overrides native word object")
dofile("tests/helpers.lua").setup()
H.buffer({ "ZbQ", "ZaQ", "", "ZdQ", "ZcQ" }, { 1, 1 })
H.keys("<C-v>jgs")
H.keys("3j.")
H.eq(H.lines(), { "ZaQ", "ZbQ", "", "ZcQ", "ZdQ" }, "block dot repeat")
H.buffer({ "A123", "B456" })
vim.o.virtualedit = "all"
local block = R.from_positions({ 0, 1, 2, 0 }, { 0, 2, 3, 0 }, "block", false)
H.eq(R.get(block), { "12", "45" }, "native block byte extraction")
vim.fn.setreg("a", "x")
E.apply("replace", block, { register = "a" })
vim.o.virtualedit = ""

H.buffer({ "one", "two", "three" })
H.keys("gxxjjgxx")
H.eq(H.lines(), { "three", "two", "one" }, "line exchange")
H.keys("u")
H.eq(H.lines(), { "one", "two", "three" })
H.buffer({ "source" })
local first_buf = vim.api.nvim_get_current_buf()
H.keys("gxiw")
H.buffer({ "target rest" })
H.keys("gxiw")
H.eq(H.lines(), { "source rest" }, "cross-buffer second target")
H.eq(vim.api.nvim_buf_get_lines(first_buf, 0, -1, true), { "target" }, "cross-buffer first target")
H.keys("u")
H.eq(H.lines(), { "target rest" }, "cross-buffer undo remains local")
vim.api.nvim_set_current_buf(first_buf)
H.keys("u")
H.eq(H.lines(), { "source" })

H.buffer({ "untouched" })
local origin = vim.api.nvim_get_current_buf()
local foreign = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(foreign, 0, -1, true, { "\ta=1", "    longer=2" })
vim.bo[foreign].tabstop = 4
E.apply("align", { start = { 0, 0 }, finish = { 1, 12 }, mode = "line" }, { buf = foreign })
H.eq(
  vim.api.nvim_buf_get_lines(foreign, 0, -1, true),
  { "    a      = 1", "    longer = 2" },
  "noncurrent buffer uses its own display columns"
)
H.eq(vim.api.nvim_get_current_buf(), origin, "programmatic operation restores current buffer")
H.eq(H.lines(), { "untouched" })

vim.opt.runtimepath:append(
  vim.env.EDITING_TOOLS_PARSER_DIR or vim.fn.expand("~/.local/share/nvim/site")
)
for _, lang in ipairs({ "lua", "python", "javascript", "typescript", "tsx" }) do
  H.eq(pcall(vim.treesitter.query.get, lang, "textobjects"), true, lang .. " query compiles")
end
H.buffer({ "function empty() end" })
vim.bo.filetype = "lua"
H.eq(H.text("f", "around"), "function empty() end", "empty function outer object")
H.buffer({ "const f = (x) => x + 1;", "class C { m() { return 1; } }" }, { 1, 18 })
vim.bo.filetype = "javascript"
H.eq(H.text("f"), "x + 1", "JavaScript arrow function")
H.buffer({ "function f(x: number): number { return x; }" }, { 1, 32 })
vim.bo.filetype = "typescript"
H.eq(
  H.text("f", "around"),
  "function f(x: number): number { return x; }",
  "TypeScript inherited query"
)

vim.cmd.runtime("plugin/editing_tools.lua")
H.buffer({ "c", "a", "b" })
vim.cmd("%EditingTools sort")
H.eq(H.lines(), { "a", "b", "c" }, "command range")
vim.cmd("EditingTools cancel")
H.eq(require("editing_tools.exchange").pending(), false)
print("regression: " .. H.count .. " assertions passed")
