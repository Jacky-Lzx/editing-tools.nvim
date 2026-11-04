local M = {}
function M.check()
  vim.health.start("editing-tools.nvim")
  if vim.fn.has("nvim-0.11") == 1 then
    vim.health.ok("Neovim 0.11+ available")
  else
    vim.health.error("Neovim 0.11+ required")
  end
  vim.health.info("No required plugin dependencies. Tree-sitter parsers are optional.")
  local lang = vim.treesitter.language.get_lang(vim.bo.filetype)
  if not lang then
    vim.health.info("No Tree-sitter language for the current filetype")
    return
  end
  local ok, parser = pcall(vim.treesitter.get_parser, 0, lang, { error = false })
  if not ok or not parser then
    vim.health.info("Optional parser not installed: " .. lang)
    return
  end
  local success, query = pcall(vim.treesitter.query.get, lang, "textobjects")
  if success and query then
    vim.health.ok("Parser and text-object query available: " .. lang)
  elseif success then
    vim.health.info("No textobjects query for " .. lang)
  else
    vim.health.error("Invalid textobjects query: " .. tostring(query))
  end
end
return M
