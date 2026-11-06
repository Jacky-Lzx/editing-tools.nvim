local M = {}
function M.check()
  vim.health.start("editing-tools.nvim")
  if vim.fn.has("nvim-0.12") == 1 then
    vim.health.ok("Neovim 0.12+ available")
  else
    vim.health.error("Neovim 0.12+ required")
  end
  if #vim.api.nvim_get_runtime_file("lua/motion_tools/init.lua", false) > 0 then
    vim.health.ok("motion-tools.nvim is available for ranges and scanning")
  else
    vim.health.error("motion-tools.nvim must be on runtimepath")
  end
end
return M
