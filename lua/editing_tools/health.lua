local M = {}

function M.check()
  vim.health.start("editing-tools.nvim")
  if vim.fn.has("nvim-0.12") == 0 then
    vim.health.error("Neovim 0.12+ is required", { "Upgrade Neovim" })
    return
  end
  local issues = {}
  local function problem(level, message, advice)
    issues[#issues + 1] = { level = level, message = message, advice = advice }
  end
  if #vim.api.nvim_get_runtime_file("lua/motion_tools/init.lua", false) == 0 then
    problem(
      "error",
      "motion-tools is unavailable; range and scanning operations cannot run.",
      { "Install/mount motion-tools.nvim" }
    )
  end

  table.sort(issues, function(a, b)
    if a.level ~= b.level then
      return a.level == "error"
    end
    return a.message < b.message
  end)
  for _, issue in ipairs(issues) do
    vim.health[issue.level](issue.message, issue.advice)
  end
  if #issues == 0 then
    vim.health.ok("Runtime requirements are satisfied.")
  end
end

return M
