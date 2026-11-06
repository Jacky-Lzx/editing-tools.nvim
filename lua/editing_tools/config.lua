local M = {}

M.defaults = {
  mappings = {
    inside = false,
    around = false,
    inside_next = false,
    around_next = false,
    inside_prev = false,
    around_prev = false,
    goto_start = false,
    goto_end = false,
    replace = false,
    exchange = false,
    multiply = false,
    sort = false,
    evaluate = false,
    align = false,
    insert_visual = false,
    append_visual = false,
  },
  search = { lines = 500, max_bytes = 1024 * 1024 },
  objects = {},
  treesitter = {
    f = { inside = "function.inner", around = "function.outer" },
    c = { inside = "class.inner", around = "class.outer" },
    o = {
      inside = { "block.inner", "conditional.inner", "loop.inner" },
      around = { "block.outer", "conditional.outer", "loop.outer" },
    },
  },
  align = {
    delimiter = "=",
    occurrence = "all",
    justify = "left",
    padding = 1,
    trim = true,
    outside = true,
  },
  sort = { ignore_case = false, numeric = false, reverse = false },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  assert(opts == nil or type(opts) == "table", "editing-tools: setup expects a table")
  opts = vim.deepcopy(opts or {})
  local result = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  assert(
    result.search.lines >= 0 and result.search.lines % 1 == 0,
    "search.lines must be a nonnegative integer"
  )
  assert(result.search.max_bytes > 0, "search.max_bytes must be positive")
  for name, lhs in pairs(result.mappings) do
    assert(
      type(lhs) == "string" or lhs == false,
      "mapping " .. name .. " must be a string or false"
    )
  end
  M.options = result
  return result
end

return M
