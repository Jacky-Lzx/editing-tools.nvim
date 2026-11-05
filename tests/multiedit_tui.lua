vim.opt.rtp:prepend(vim.fn.getcwd())
vim.o.swapfile, vim.o.shadafile = false, "NONE"
vim.o.timeoutlen, vim.o.ttimeoutlen = 150, 20
vim.o.showmode, vim.o.ruler = false, false
vim.o.autoindent, vim.o.smartindent = false, false
local E = require("editing_tools")
local H = require("tests.helpers")
E.setup()
local directory = assert(vim.env.EDITING_TOOLS_TEST_DIR)
local cases, index = {}, 0
local function case(name, input, setup, verify)
  cases[#cases + 1] = { name = name, input = input, setup = setup, verify = verify }
end
local function active()
  return require("editing_tools.multiedit").is_active()
end
local function clean()
  H.eq(active(), false)
  for _, name in ipairs({ "editing_tools.multiedit.cursors", "editing_tools.multiedit.ranges" }) do
    H.eq(#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces()[name], 0, -1, {}), 0)
  end
end
case("begin-indent-insert", "V3jmI", function()
  H.buffer({ "  one", "\ttwo", "", "three" })
end, function()
  H.eq(vim.fn.mode(), "i")
  H.eq(active(), true)
  H.eq(H.lines(), { "  one", "\ttwo", "", "three" })
  H.eq(
    #vim.api.nvim_buf_get_extmarks(
      0,
      vim.api.nvim_get_namespaces()["editing_tools.multiedit.cursors"],
      0,
      -1,
      {}
    ),
    3
  )
end)
case("live-unicode", "你好", nil, function()
  H.eq(H.lines(), { "  你好one", "\t你好two", "你好", "你好three" })
  H.eq(vim.fn.mode(), "i")
end)
case("live-backspace", "\127", nil, function()
  H.eq(H.lines(), { "  你one", "\t你two", "你", "你three" })
end)
case("finish", "\27", nil, function()
  H.eq(vim.fn.mode(), "n")
  clean()
end)
case("single-undo", "u", nil, function()
  H.eq(H.lines(), { "  one", "\ttwo", "", "three" })
end)
case("redo", "\18", nil, function()
  H.eq(H.lines(), { "  你one", "\t你two", "你", "你three" })
end)
case("append-live", "V2jmA!", function()
  H.buffer({ "a", "long", "" })
end, function()
  H.eq(H.lines(), { "a!", "long!", "!" })
  H.eq(vim.fn.mode(), "i")
end)
case("multiline-live", "\rX", nil, function()
  H.eq(H.lines(), { "a!", "X", "long!", "X", "!", "X" })
  H.eq(vim.api.nvim_win_get_cursor(0), { 6, 1 })
end)
case("multiline-finish-undo", "\27u", nil, function()
  H.eq(H.lines(), { "a", "long", "" })
  clean()
end)
case("register-insert", "VjmI\18a", function()
  H.buffer({ "a", "b" })
  vim.fn.setreg("a", "中$", "v")
end, function()
  H.eq(H.lines(), { "中$a", "中$b" })
  H.eq(vim.fn.getreg("a"), "中$")
end)
case("control-c", "\3", nil, function()
  clean()
  H.eq(vim.fn.mode(), "n")
end)
case("block-live", "\22jlmI#", function()
  H.buffer({ "abcd", "xyzz" }, { 1, 1 })
end, function()
  H.eq(H.lines(), { "a#bcd", "x#yzz" })
  H.eq(vim.fn.mode(), "i")
end)
case("block-undo", "\27u", nil, function()
  H.eq(H.lines(), { "abcd", "xyzz" })
  clean()
end)
case("block-tab-padding", "\22jjlmA!", function()
  H.buffer({ "\tA", "abcd", "" })
  vim.bo.tabstop = 4
  vim.wo.virtualedit = "all"
  vim.fn.setpos(".", { 0, 1, 1, 1 })
end, function()
  H.eq(H.lines(), { "   ! A", "abc!d", "   !" })
end)
case("block-tab-undo", "\27u", nil, function()
  H.eq(H.lines(), { "\tA", "abcd", "" })
  clean()
  vim.wo.virtualedit = ""
end)
case("empty-block-cancel", "\22jjlmA\27", function()
  H.buffer({ "\tA", "abcd", "" })
  vim.bo.modified = false
  vim.bo.tabstop = 4
  vim.wo.virtualedit = "all"
  vim.fn.setpos(".", { 0, 1, 1, 1 })
end, function()
  H.eq(H.lines(), { "\tA", "abcd", "" })
  H.eq(vim.bo.modified, false)
  clean()
  vim.wo.virtualedit = ""
end)
case("reverse-selection", "VkmA中", function()
  H.buffer({ "first", "last" }, { 2, 0 })
end, function()
  H.eq(H.lines(), { "first中", "last中" })
  H.eq(vim.api.nvim_win_get_cursor(0), { 1, #"first中" })
end)
case("reverse-finish", "\27", nil, clean)
case("pairs-live", "VjmI(", function()
  H.buffer({ "", "" })
  vim.opt.rtp:append(vim.fn.fnamemodify(vim.fn.getcwd(), ":h") .. "/pairs.nvim")
  require("pairs").setup({})
end, function()
  H.eq(H.lines(), { "()", "()" })
  H.eq(vim.api.nvim_win_get_cursor(0), { 2, 1 })
end)
case("pairs-type", "word)", nil, function()
  H.eq(H.lines(), { "(word)", "(word)" })
end)
case("pairs-finish-undo", "\27u", nil, function()
  H.eq(H.lines(), { "", "" })
  clean()
end)

case("combining-append", "VjmA!", function()
  H.buffer({ "é", "á" })
end, function()
  H.eq(H.lines(), { "é!", "á!" })
end)
case("combining-undo", "\27u", nil, function()
  H.eq(H.lines(), { "é", "á" })
  clean()
end)
case("cursor-edit", "VjmIab", function()
  H.buffer({ "x", "y" })
end, function()
  H.eq(H.lines(), { "abx", "aby" })
end)
case("cursor-left-edit", "\27[DZ", nil, function()
  H.eq(H.lines(), { "aZbx", "aZby" })
end)
case("cursor-finish", "\27", nil, clean)
case("buffer-leave", "VjmA!", function()
  H.buffer({ "left", "right" })
end, function()
  local source = vim.api.nvim_get_current_buf()
  local other = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_set_current_buf(other)
  H.eq(active(), false)
  H.eq(vim.api.nvim_buf_get_lines(source, 0, -1, false), { "left!", "right!" })
  vim.cmd("stopinsert")
end)

case("burst-input", "V2jmI" .. string.rep("x", 300), function()
  H.buffer({ "a", "b", "c" })
end, function()
  H.eq(
    H.lines(),
    { string.rep("x", 300) .. "a", string.rep("x", 300) .. "b", string.rep("x", 300) .. "c" }
  )
end)
case("burst-finish", "\27", nil, clean)
case("burst-undo", "u", nil, function()
  H.eq(H.lines(), { "a", "b", "c" })
end)

case("block-end-of-line", "\22j$mA!", function()
  H.buffer({ "abc", "longer" }, { 1, 1 })
end, function()
  H.eq(H.lines(), { "abc!", "longer!" })
end)
case("block-end-finish", "\27", nil, clean)
case("exclusive-block", "\22jlmA!", function()
  H.buffer({ "abcd", "xyzz" }, { 1, 1 })
  vim.o.selection = "exclusive"
end, function()
  H.eq(H.lines(), { "ab!cd", "xy!zz" })
end)
case("exclusive-finish", "\27", nil, function()
  clean()
  vim.o.selection = "inclusive"
end)
case("external-edit-start", "VjmIabc", function()
  H.buffer({ "left", "right" })
end, function()
  H.eq(H.lines(), { "abcleft", "abcright" })
  vim.api.nvim_buf_set_text(0, 0, 0, 0, 3, { "external" })
end)
case("external-edit-stop", "\27", nil, function()
  H.eq(H.lines(), { "externalleft", "abcright" })
  clean()
end)

local function finish(error)
  vim.fn.writefile({
    error and "FAIL " .. tostring(error)
      or "PASS multi-insert PTY: " .. #cases .. " stages, " .. H.count .. " assertions",
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
vim.keymap.set({ "n", "i" }, "<F12>", function()
  vim.cmd("redraw!")
  local ok, err = xpcall(cases[index].verify, debug.traceback)
  if not ok then
    finish(cases[index].name .. ": " .. err)
    return
  end
  vim.schedule(next_case)
end)
vim.defer_fn(next_case, 100)
