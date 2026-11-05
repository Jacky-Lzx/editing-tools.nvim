vim.opt.rtp:prepend(vim.fn.getcwd())
local parent = vim.fn.fnamemodify(vim.fn.getcwd(), ":h")
if vim.fn.isdirectory(parent .. "/toolchain-tools.nvim") == 1 then
  vim.opt.rtp:append(parent .. "/toolchain-tools.nvim")
  require("toolchain.parsers").setup({})
  require("toolchain.parsers").activate()
end
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
local H = require("tests.helpers")
require("editing_tools").setup()
local languages = {
  "lua",
  "python",
  "javascript",
  "typescript",
  "tsx",
  "bash",
  "fish",
  "c",
  "cpp",
  "cuda",
  "cmake",
  "rust",
  "swift",
  "java",
  "systemverilog",
  "gdscript",
  "matlab",
  "nix",
  "html",
  "css",
  "json",
  "yaml",
  "toml",
  "markdown",
  "latex",
  "bibtex",
  "vue",
}
local loaded, skipped = {}, {}
for _, lang in ipairs(languages) do
  if pcall(vim.treesitter.language.add, lang) then
    local ok, query = pcall(vim.treesitter.query.get, lang, "textobjects")
    assert(ok and query, lang .. ": " .. tostring(query))
    loaded[lang] = true
    for _, file in ipairs(vim.treesitter.query.get_files(lang, "textobjects")) do
      assert(not file:find("nvim%-treesitter%-textobjects"), "external query dependency: " .. file)
    end
  else
    skipped[#skipped + 1] = lang
  end
end
local examples = {
  lua = { "local function value()", "  local first = 1", "  return first", "end" },
  python = { "def value():", "    first = 1", "    return first" },
  javascript = { "function value() {", "  const first = 1;", "  return first;", "}" },
  typescript = { "function value(): number {", "  const first = 1;", "  return first;", "}" },
  rust = { "fn value() -> i32 {", "  let first = 1;", "  first", "}" },
  c = { "int value(void) {", "  int first = 1;", "  return first;", "}" },
  cpp = { "int value() {", "  int first = 1;", "  return first;", "}" },
  cuda = { "__device__ int value() {", "  int first = 1;", "  return first;", "}" },
  swift = { "func value() -> Int {", "  let first = 1", "  return first", "}" },
  bash = { "value() {", "  first=1", '  echo "$first"', "}" },
  fish = { "function value", "  set first 1", "  echo $first", "end" },
  java = { "class A {", "  int value() {", "    int first = 1;", "    return first;", "  }", "}" },
  gdscript = { "func value():", "    var first = 1", "    return first" },
  matlab = { "function out = value()", "  first = 1;", "  out = first;", "end" },
}
for lang, lines in pairs(examples) do
  if loaded[lang] then
    local row = lang == "java" and 3 or 2
    H.buffer(lines, { row, 4 })
    vim.bo.filetype = lang
    vim.treesitter.start(0, lang)
    local text = H.text("f")
    assert(
      text and text:find("first", 1, true),
      lang .. ": missing function body: " .. tostring(text)
    )
    H.keys("dif")
    assert(
      not table.concat(H.lines(), "\n"):find("first", 1, true),
      lang .. ": quantified body must include every statement: " .. vim.inspect(H.lines())
    )
    H.keys("u")
    H.eq(H.lines(), lines, lang .. ": native undo")
    vim.treesitter.stop()
  end
end
print(
  "Query migration: "
    .. vim.tbl_count(loaded)
    .. " grammars compiled; native multi-statement function edits and undo passed"
)
if #skipped > 0 then
  print("Unavailable optional parsers: " .. table.concat(skipped, ", "))
end
