local H = require("tests.helpers")
local E = require("editing_tools")
local A = require("editing_tools.align")
E.setup()
H.eq(A.lines({ "a=1", "long = 2" }), { "a    = 1", "long = 2" }, "basic alignment")
H.eq(
  A.lines({ "  a=1", "  long = 2", "\tuntouched " }),
  { "  a    = 1", "  long = 2", "\tuntouched " },
  "indent and unmatched preservation"
)
H.eq(
  A.lines({ "x = { a=1 }", 'long = "a=b"' }),
  { "x    = { a=1 }", 'long = "a=b"' },
  "protect nested and quoted delimiters"
)
H.eq(
  A.lines({ "a = {", "  nested=1", "}", "long=2" }),
  { "a    = {", "  nested=1", "}", "long = 2" },
  "carry nesting between rows"
)
H.eq(A.lines({ "a=1=2", "long=22=3" }), { "a    = 1  = 2", "long = 22 = 3" }, "multiple columns")
H.eq(A.lines({ "a=1=2", "long=22=3" }, { occurrence = "first" }), { "a    = 1=2", "long = 22=3" })
H.eq(A.lines({ "a=1=2", "long=22=3" }, { occurrence = "last" }), { "a=1     = 2", "long=22 = 3" })
H.eq(
  A.lines({ "你=>1", "abcd=>2" }, { delimiter = "=>" }),
  { "你   => 1", "abcd => 2" },
  "wide character display columns"
)
H.eq(A.lines({ "a=1", "long=2" }, { justify = "right", padding = 0 }), { "   a=1", "long=2" })
H.eq(
  A.lines({ "\ta=1", "    longer=2" }, { tabstop = 4 }),
  { "    a      = 1", "    longer = 2" },
  "tab widths"
)
H.eq(
  A.lines({ 'x="a=b"', 'long="c=dd"' }, { outside = false }),
  { 'x    = "a = b"', 'long = "c = dd"' },
  "filter disabled"
)
H.eq(pcall(A.lines, { "a=1" }, { delimiter = "" }), false)

-- Expected results follow mini.align's built-in '=' modifier.
local equals_input = { "a=b", "aa<=bb", "aaa===bbb", "aaaa   =   cccc" }
local equals_output = { "a    =   b", "aa   <=  bb", "aaa  === bbb", "aaaa =   cccc" }
H.eq(A.lines(equals_input, { preset = "equals" }), equals_output, "operator columns")
H.eq(
  A.lines({ "x=1=2", "long+=22==3" }, { preset = "equals" }),
  { "x    =  1  =  2", "long += 22 == 3" },
  "multiple operator columns"
)
H.eq(
  A.lines({ "a=1", "long=2" }, { preset = "equals", columns = { 3, 0 } }),
  { "a = 1", "long = 2" },
  "characterwise first-line offset"
)
H.eq(
  A.lines({ "a=", "long+=", "value" }, { preset = "equals" }),
  { "a    =", "long +=", "value" },
  "final operators do not create trailing whitespace"
)
H.eq(
  A.lines({ "=1", "==2" }, { preset = "equals" }),
  { "=  1", "== 2" },
  "leading operators do not add indentation"
)
H.eq(
  A.lines({ "x=1=2", "long+=22==3" }, { preset = "equals", justify = "right" }),
  { "   x  =  1  = 2", "long += 22 == 3" },
  "right-justified operator columns"
)

H.buffer(equals_input)
local original_tick = vim.api.nvim_buf_get_changedtick(0)
local original_undo = vim.fn.undotree().seq_cur
local equals_calls = 0
vim.keymap.set("n", "=", function()
  equals_calls = equals_calls + 1
end, { buffer = true })
H.keys("V3jga=")
H.eq(A.is_active(), true, "ga= keeps the user's original preview workflow")
H.eq(H.lines(), equals_input, "equals preview keeps source unchanged")
H.eq(vim.api.nvim_buf_get_changedtick(0), original_tick)
H.eq(vim.fn.undotree().seq_cur, original_undo)
H.keys("<CR>")
H.eq(A.is_active(), false)
H.eq(H.lines(), equals_output, "Visual ga= applies complete operators")
H.keys("=")
H.eq(equals_calls, 1, "restore existing equals mapping")
vim.keymap.del("n", "=", { buffer = true })
H.keys("u")
H.eq(H.lines(), equals_input, "ga= is one undo step")
H.keys("<C-r>")
H.eq(H.lines(), equals_output, "ga= redo")

H.buffer({ "x=1=2", "long+=22==3", "", "z=4=5", "longer+=66==7" })
H.keys("2gaa=<CR>3j0.")
H.eq(
  H.lines(),
  { "x    =  1  =  2", "long += 22 == 3", "", "z      =  4  =  5", "longer += 66 == 7" },
  "dot repeats the equals preset without preview"
)
H.eq(A.is_active(), false)
H.buffer({ 'x="a=b"', 'long="c=dd"' })
H.keys("Vjga=<CR>")
H.eq(H.lines(), { 'x    = "a = b"', 'long = "c = dd"' }, "equals includes quoted operators")
H.buffer({ "a=(b=1)", "long=(cc+=2)" })
H.keys("gaip=<CR>")
H.eq(H.lines(), { "a    = (b  =  1)", "long = (cc += 2)" }, "equals includes nested operators")
H.buffer(equals_input)
H.keys("V3jga=<Esc>")
H.eq(A.is_active(), false)
H.eq(H.lines(), equals_input, "cancel equals preview")
H.eq(vim.fn.maparg("=", "n"), "", "remove temporary equals mapping")
H.keys(".")
H.eq(H.lines(), equals_input, "cancelled equals alignment does not repeat")

H.buffer({ "a=1", "long=2", "", "b=3", "larger=4" })
local original = H.lines()
local tick = vim.api.nvim_buf_get_changedtick(0)
local undo = vim.fn.undotree().seq_cur
H.keys("gaiz")
H.eq(A.is_active(), false)
H.keys("2gaa")
H.eq(A.is_active(), true, "operator opens preview")
H.eq(H.lines(), original, "preview keeps source unchanged")
H.eq(vim.api.nvim_buf_get_changedtick(0), tick, "preview leaves changedtick unchanged")
H.eq(vim.fn.undotree().seq_cur, undo, "preview leaves undo unchanged")
H.keys("<Esc>")
H.eq(A.is_active(), false)
H.eq(H.lines(), original, "cancel")
H.keys("2gaa<CR>")
H.eq(H.lines(), { "a    = 1", "long = 2", "", "b=3", "larger=4" }, "confirm")
H.keys("3j0.")
H.eq(
  H.lines(),
  { "a    = 1", "long = 2", "", "b      = 3", "larger = 4" },
  "dot repeats options without preview"
)
H.eq(A.is_active(), false)
H.keys("u")
H.eq(H.lines()[4], "b=3", "alignment single undo")

H.buffer({ "x:1", "long:2" })
local old_input = vim.ui.input
vim.ui.input = function(_, callback)
  callback(":")
end
H.keys("Vjga=d<CR>")
vim.ui.input = old_input
H.eq(H.lines(), { "x    : 1", "long : 2" }, "Visual delimiter prompt")

H.buffer({ "a=1", "long=2" })
local calls = 0
vim.keymap.set("n", "j", function()
  calls = calls + 1
end, { buffer = true })
local old_mapping = vim.fn.maparg("j", "n", false, true)
H.keys("2gaa")
H.eq(A.is_active(), true)
H.keys("j<Esc>")
H.eq(
  vim.fn.maparg("j", "n", false, true).callback,
  old_mapping.callback,
  "restore buffer-local mapping"
)
H.keys("j")
H.eq(calls, 1)
H.keys("2gaa")
local buf = vim.api.nvim_get_current_buf()
vim.cmd.enew()
H.eq(A.is_active(), false, "leaving buffer cancels")
vim.api.nvim_set_current_buf(buf)
H.eq(vim.fn.maparg("j", "n", false, true).callback, old_mapping.callback, "cleanup on buffer leave")
vim.keymap.del("n", "j", { buffer = true })

H.keys("2gaa")
vim.api.nvim_buf_set_lines(0, 0, 1, true, { "changed=5" })
H.keys("<CR>")
H.eq(H.lines(), { "changed=5", "long=2" }, "concurrent changes reject confirmation")
H.eq(A.is_active(), false)
H.keys("2gaa")
H.keys("iX<Esc>")
H.eq(A.is_active(), false, "insert cancels preview")
H.eq(H.lines()[1], "Xchanged=5")
H.buffer({ "[a=1]", "[long=2]" }, { 1, 1 })
H.keys("<C-v>j6lga")
H.eq(A.is_active(), true, "block preview")
H.keys("<Esc>")
H.eq(H.lines(), { "[a=1]", "[long=2]" })
print("align: " .. H.count .. " assertions passed")
