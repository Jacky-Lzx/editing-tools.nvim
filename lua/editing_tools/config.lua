local M = {}

M.defaults = {
  mappings = {
    inside = "i",
    around = "a",
    inside_next = "in",
    around_next = "an",
    inside_prev = "il",
    around_prev = "al",
    goto_start = "g[",
    goto_end = "g]",
    replace = "cr",
    exchange = "gx",
    multiply = "gm",
    sort = "gs",
    evaluate = "g=",
    align = "ga",
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
  opts = opts or {}
  vim.validate("opts", opts, "table")
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
