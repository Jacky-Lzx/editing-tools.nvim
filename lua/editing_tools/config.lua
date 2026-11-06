local M = {}

M.defaults = {
  mappings = {
    replace = false,
    exchange = false,
    multiply = false,
    sort = false,
    evaluate = false,
    align = false,
    insert_visual = false,
    append_visual = false,
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
