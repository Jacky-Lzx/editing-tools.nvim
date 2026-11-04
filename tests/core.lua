local H = require("tests.helpers")
local E = require("editing_tools")
E.setup()
H.buffer({ 'foo({a, (b, c)}, "x,y", z)' }, { 1, 9 })
H.eq(H.text("b"), "b, c", "smallest enclosing bracket")
H.eq(H.text("b", "inside", { count = 2 }), "a, (b, c)", "nested count")
H.eq(H.text("b", "inside", { count = 3 }), '{a, (b, c)}, "x,y", z')
H.eq(H.text("a"), "b")
H.buffer({ 'foo(a, nested(b,c), "x,y", z)' }, { 1, 8 })
H.eq(H.text("a"), "nested(b,c)")
H.eq(H.text("a", "around"), " nested(b,c), ")
H.eq(H.text("u", "around"), "nested(b,c)")
H.buffer({ 'hello "你好吗" (x)' }, { 1, 9 })
H.eq(H.text("q"), "你好吗")
H.keys("diq")
H.eq(H.lines(), { 'hello "" (x)' }, "operator text object")
H.keys("u")
H.eq(H.lines(), { 'hello "你好吗" (x)' }, "UTF-8 undo")
H.buffer({ "(a (b) c)" }, { 1, 4 })
H.keys("d2ib")
H.eq(H.lines(), { "()" }, "count with operator")
H.buffer({ "camelHTTPServer snake_case 123" })
H.eq(H.text("e"), "camel")
H.eq(H.text("e", "inside", { direction = "next", count = 2 }), "Server")
H.eq(H.text("d"), "123")
H.keys("diw")
H.eq(H.lines(), { " snake_case 123" }, "native word fallback")
H.buffer({ "<div><b>你好</b></div>" }, { 1, 10 })
H.eq(H.text("t"), "你好")
H.eq(H.text("t", "around", { count = 2 }), "<div><b>你好</b></div>")
H.buffer({ "(a) (b) (c)" }, { 1, 5 })
H.eq(H.text("b", "inside", { direction = "next" }), "c")
H.eq(H.text("b", "inside", { direction = "prev" }), "a")
H.buffer({ "x (a)" })
H.keys("dib")
H.eq(H.lines(), { "x ()" }, "forward lookup")
H.buffer({ "nothing" })
H.keys("dib")
H.eq(H.lines(), { "nothing" }, "missing object cancels")
H.eq(vim.fn.mode(), "n")
H.buffer({ "(one (two) three)" }, { 1, 7 })
H.keys("vibibd")
H.eq(H.lines(), { "()" }, "visual expansion")
H.buffer({ "first", "  a", "  b", "last" }, { 2, 2 })
H.eq(H.text("i"), "  a\n  b")
H.eq(H.text("g"), "first\n  a\n  b\nlast")
H.buffer({ "(a) (b)" }, { 1, 1 })
H.keys("cibX<Esc>j")
H.eq(H.lines(), { "(X) (b)" }, "change object")
H.keys("$h.")
H.eq(H.lines(), { "(X) (X)" }, "native change repeat")

E.setup({
  objects = {
    z = function(ctx)
      return { { start = { ctx.pos[1], 0 }, finish = { ctx.pos[1], 1 } } }
    end,
  },
})
H.buffer({ "abc" })
H.keys("diz")
H.eq(H.lines(), { "bc" }, "custom provider")
E.setup({ mappings = { inside = false } })
H.eq(vim.fn.maparg("i", "o"), "", "setup removes previous mappings")
E.setup()

vim.opt.runtimepath:append(
  vim.env.EDITING_TOOLS_PARSER_DIR or vim.fn.expand("~/.local/share/nvim/site")
)
H.buffer(
  { "local function f(x)", "  return x + 1", "end", "", "local g = function() return 2 end" },
  { 2, 3 }
)
vim.bo.filetype = "lua"
H.eq(H.text("f"), "return x + 1", "Lua parser query")
H.eq(H.text("f", "around"), "local function f(x)\n  return x + 1\nend")
H.keys("dif")
H.eq(H.lines()[2], "  ", "Tree-sitter operator")
vim.treesitter.query.set(
  "lua",
  "textobjects",
  [[
  (function_declaration body: (block (_)+ @function.inner)) @function.outer
]]
)
H.buffer({
  "function f()",
  "  local a = 1",
  "  local b = 2",
  "  return a + b",
  "end",
  "function g()",
  "  return 3",
  "end",
}, { 3, 3 })
vim.bo.filetype = "lua"
H.eq(
  H.text("f"),
  "local a = 1\n  local b = 2\n  return a + b",
  "quantified capture spans the whole function body"
)
H.eq(
  H.text("f", "inside", { direction = "next" }),
  "return 3",
  "separate query matches stay separate"
)
H.keys("dif")
H.eq(
  H.lines(),
  { "function f()", "  ", "end", "function g()", "  return 3", "end" },
  "quantified capture deletion"
)
vim.treesitter.query.set("lua", "textobjects", nil)
H.buffer(
  { "class C:", "    def f(self):", "        return 1", "", "def g():", "    pass" },
  { 3, 8 }
)
vim.bo.filetype = "python"
H.eq(H.text("f"), "return 1", "Python function")
H.eq(H.text("c", "around"), "class C:\n    def f(self):\n        return 1", "Python class")
H.buffer({ "local x = 1" })
vim.bo.filetype = "not_a_language"
H.eq(H.text("f"), nil, "missing parser")
print("core: " .. H.count .. " assertions passed")
