vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.swapfile, vim.o.shadafile = false, "NONE"
vim.o.timeoutlen, vim.o.ttimeoutlen = 150, 20
vim.o.showmode, vim.o.ruler = false, false
local E = require("editing_tools")
local H = require("tests.helpers")
local A = require("editing_tools.align")
dofile("tests/helpers.lua").setup()
local directory = assert(vim.env.EDITING_TOOLS_TEST_DIR)
local cases, index = {}, 0
local function case(name, input, setup, verify)
  cases[#cases + 1] = { name = name, input = input, setup = setup, verify = verify }
end
local function screen_line(row)
  local position = vim.fn.screenpos(0, row, 1)
  local text = ""
  for col = position.col, position.col + 30 do
    text = text .. vim.fn.screenstring(position.row, col)
  end
  return text:gsub("%s+$", "")
end
case("change-and-dot", "cib你好\27w.", function()
  H.buffer({ "(a) (b)" }, { 1, 1 })
end, function()
  H.eq(H.lines(), { "(你好) (你好)" })
  H.eq(vim.fn.mode(), "n")
end)
case("repeat-into-empty", "cibX\27$h.", function()
  H.buffer({ "(a) () ()" }, { 1, 1 })
end, function()
  H.eq(H.lines(), { "(X) () (X)" })
  H.eq(vim.fn.mode(), "n")
end)
case("repeat-after-empty", "0f)2l.", nil, function()
  H.eq(H.lines(), { "(X) (X) (X)" })
end)
case("operator-cancel", "gmi\27", function()
  H.buffer({ "keep me" })
end, function()
  H.eq(H.lines(), { "keep me" })
  H.eq(vim.fn.mode(), "n")
end)
case("exchange-highlight", "gxiw", function()
  H.buffer({ "alpha beta gamma" })
end, function()
  H.eq(H.lines(), { "alpha beta gamma" })
  H.eq(
    #vim.api.nvim_buf_get_extmarks(
      0,
      vim.api.nvim_get_namespaces()["editing_tools.exchange"],
      0,
      -1,
      {}
    ),
    1
  )
end)
case("exchange-confirm", "wwgxiw", nil, function()
  H.eq(H.lines(), { "gamma beta alpha" })
end)
case("exchange-undo", "u", nil, function()
  H.eq(H.lines(), { "alpha beta gamma" })
end)
case("alignment-preview", "2gaa", function()
  H.buffer({ "a=1", "long=2", "", "b=3", "larger=4" })
end, function()
  H.eq(A.is_active(), true)
  H.eq(H.lines()[1], "a=1")
  H.eq(screen_line(1), "a    = 1", "actual preview screen")
  H.eq(vim.fn.mode(), "n")
end)
case("alignment-cancel", "\27", nil, function()
  H.eq(A.is_active(), false)
  H.eq(screen_line(1), "a=1", "screen restored after cancel")
  H.eq(#vim.api.nvim_list_wins(), 1)
end)
case("alignment-control-c", "2gaa\3", nil, function()
  H.eq(A.is_active(), false)
  H.eq(H.lines()[1], "a=1")
end)
case("alignment-confirm", "2gaa\r", nil, function()
  H.eq(H.lines()[1], "a    = 1")
  H.eq(A.is_active(), false)
end)
case("alignment-dot", "3j0.", nil, function()
  H.eq(H.lines(), { "a    = 1", "long = 2", "", "b      = 3", "larger = 4" })
  H.eq(#vim.api.nvim_list_wins(), 1)
end)
case("alignment-undo", "u", nil, function()
  H.eq(H.lines()[4], "b=3")
end)
local equals_input = { "a=b", "aa<=bb", "aaa===bbb", "aaaa   =   cccc" }
local equals_output = { "a    =   b", "aa   <=  bb", "aaa  === bbb", "aaaa =   cccc" }
case("equals-preview", "V3jga=", function()
  H.buffer(equals_input)
end, function()
  H.eq(A.is_active(), true)
  H.eq(H.lines(), equals_input)
  H.eq(screen_line(1), equals_output[1], "equals operator preview screen")
  H.eq(screen_line(2), equals_output[2], "compound operator preview screen")
end)
case("equals-cancel", "\27", nil, function()
  H.eq(A.is_active(), false)
  H.eq(H.lines(), equals_input)
  H.eq(screen_line(1), equals_input[1], "equals cancel restores screen")
  H.eq(vim.fn.maparg("=", "n"), "", "equals binding cleaned up")
end)
case("equals-confirm", "4gaa=\r", function()
  H.buffer(vim.list_extend(vim.list_extend(vim.deepcopy(equals_input), { "" }), equals_input))
end, function()
  H.eq(A.is_active(), false)
  H.eq(
    H.lines(),
    vim.list_extend(vim.list_extend(vim.deepcopy(equals_output), { "" }), equals_input)
  )
  H.eq(#vim.api.nvim_list_wins(), 1)
end)
case("equals-dot", "5j0.", nil, function()
  H.eq(
    H.lines(),
    vim.list_extend(vim.list_extend(vim.deepcopy(equals_output), { "" }), equals_output)
  )
  H.eq(A.is_active(), false)
end)
case("equals-undo", "u", nil, function()
  H.eq(H.lines()[6], equals_input[1])
end)
case("equals-characterwise", "vj$ga=\r", function()
  H.buffer({ "pre a=1", "long=2" }, { 1, 4 })
end, function()
  H.eq(H.lines(), { "pre a = 1", "long  = 2" }, "characterwise equals display columns")
end)
case("equals-blockwise", "\22j6lga=\r", function()
  H.buffer({ "[a=1    ]", "[long+=2]" }, { 1, 1 })
end, function()
  H.eq(H.lines(), { "[a    =  1]", "[long += 2]" }, "blockwise equals preserves surrounding text")
end)
case("preview-insert-start", "2gaa", function()
  H.buffer({ "a=1", "long=2" })
end, function()
  H.eq(A.is_active(), true)
end)
case("preview-insert-cancel", "iX\27", nil, function()
  H.eq(A.is_active(), false)
  H.eq(H.lines(), { "Xa=1", "long=2" })
  H.eq(#vim.api.nvim_list_wins(), 1)
end)
case("named-register", '"acriw', function()
  H.buffer({ "word tail" })
  vim.fn.setreg("a", "替换", "v")
  vim.fn.setreg('"', "preserved", "v")
end, function()
  H.eq(H.lines(), { "替换 tail" })
  H.eq(vim.fn.getreg('"'), "preserved")
end)
case("exclusive-unicode", "dib", function()
  H.buffer({ "你好 (值)" }, { 1, #"你好 (" })
  vim.o.selection = "exclusive"
end, function()
  H.eq(H.lines(), { "你好 ()" })
  vim.o.selection = "inclusive"
end)
case("block-sort", "\22jgs", function()
  H.buffer({ "ZbQ", "ZaQ" }, { 1, 1 })
end, function()
  H.eq(H.lines(), { "ZaQ", "ZbQ" })
  H.eq(vim.fn.mode(), "n")
end)
case("multiline-object", "dib", function()
  H.buffer({ "(", "  one", "  two", ")" }, { 2, 2 })
end, function()
  H.eq(H.lines(), { "(", "  ", ")" })
end)

local function finish(error)
  vim.fn.writefile({
    error and "FAIL " .. tostring(error)
      or "PASS PTY: " .. #cases .. " stages, " .. H.count .. " assertions",
  }, directory .. "/result")
  vim.cmd(error and "cquit 1" or "qa!")
end
local function next_case()
  index = index + 1
  local current = cases[index]
  if not current then
    finish()
    return
  end
  local ok, err = xpcall(function()
    if current.setup then
      current.setup()
    end
    vim.cmd("redraw!")
    vim.fn.writefile({ tostring(index), vim.json.encode(current.input) }, directory .. "/stage")
  end, debug.traceback)
  if not ok then
    finish(err)
  end
end
vim.keymap.set("n", "<F12>", function()
  vim.cmd("redraw!")
  local ok, err = xpcall(cases[index].verify, debug.traceback)
  if not ok then
    finish(cases[index].name .. ": " .. err)
    return
  end
  vim.schedule(next_case)
end)
vim.defer_fn(next_case, 100)
