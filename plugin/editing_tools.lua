if vim.g.loaded_editing_tools then
  return
end
vim.g.loaded_editing_tools = true

require("editing_tools.user_command").create("EditingTools", function(args)
  require("editing_tools").command(args)
end, {
  nargs = "+",
  range = true,
  desc = "Edit a line range, or cancel an exchange/alignment",
  complete = function(lead, line)
    if #vim.split(line, "%s+") > 2 then
      return {}
    end
    return vim.tbl_filter(function(value)
      return value:sub(1, #lead) == lead
    end, {
      "align",
      "cancel",
      "evaluate",
      "exchange",
      "multiply",
      "replace",
      "sort",
      "titlecase",
    })
  end,
})
