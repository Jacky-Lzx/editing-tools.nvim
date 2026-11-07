local M = {}
local owned = {}

local function global_mapping(mode, lhs)
  local current = vim.fn.maparg(lhs, mode, false, true)
  if not next(current) then
    return nil
  end
  if current.buffer == 0 then
    return current
  end
  -- maparg() sees buffer-local overrides first. Ownership concerns the global
  -- mapping underneath, so enumerate only in that exceptional case.
  local raw = current.lhsraw or vim.keycode(current.lhs)
  for _, mapping in ipairs(vim.api.nvim_get_keymap(mode)) do
    if mapping.lhsraw == raw or vim.keycode(mapping.lhs) == raw then
      mapping.buf = nil
      return mapping
    end
  end
end

local function map(mode, lhs, rhs, desc, expr, action)
  if action then
    local plug = "<Plug>(EditingTools-" .. action .. ")"
    map(mode, plug, rhs, desc, expr)
    if lhs and lhs ~= "" then
      map(mode, lhs, plug, desc)
    end
    return
  end
  if not lhs or lhs == "" then
    return
  end
  local previous = global_mapping(mode, lhs)
  vim.keymap.set(
    mode,
    lhs,
    rhs,
    { desc = "Editing: " .. desc, expr = expr or false, silent = true }
  )
  local installed = assert(global_mapping(mode, lhs))
  owned[#owned + 1] = {
    mode = mode,
    lhs = installed.lhs,
    installed = installed,
    previous = previous and next(previous) and previous or nil,
  }
end

local function clear_mappings()
  -- Global ownership must be checked beneath buffer-local overrides.
  local snapshots = {}
  for index = #owned, 1, -1 do
    local item = owned[index]
    local maps = snapshots[item.mode]
    if not maps then
      maps = {}
      for _, mapping in ipairs(vim.api.nvim_get_keymap(item.mode)) do
        mapping.buf = nil
        maps[mapping.lhs] = mapping
      end
      snapshots[item.mode] = maps
    end
    local current = maps[item.lhs]
    if current and vim.deep_equal(current, item.installed) then
      vim.keymap.del(item.mode, item.lhs)
      if item.previous then
        vim.fn.mapset(item.mode, false, item.previous)
      end
      maps[item.lhs] = item.previous
    end
  end
  owned = {}
end

function M.dispose()
  for name, method in pairs({
    multiedit = "stop",
    align = "cancel",
    exchange = "cancel",
    operators = "abort",
  }) do
    local module = package.loaded["editing_tools." .. name]
    if module then
      module[method]()
    end
  end
  clear_mappings()
  pcall(vim.api.nvim_del_augroup_by_name, "EditingToolsObjectCancellation")
  require("editing_tools.config").setup()
end

function M.setup(opts)
  -- Validate before cancelling active edits or replacing mappings.
  local config = require("editing_tools.config").setup(opts)
  for name, method in pairs({ multiedit = "stop", align = "cancel", exchange = "cancel" }) do
    local module = package.loaded["editing_tools." .. name]
    if module then
      module[method]()
    end
  end
  clear_mappings()
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("EditingToolsObjectCancellation", { clear = true }),
    pattern = "MotionToolsObjectCancelled",
    callback = function()
      local operators = package.loaded["editing_tools.operators"]
      if operators then
        operators.abort()
      end
    end,
  })
  map("x", config.mappings.insert_visual, function()
    M.insert_visual()
  end, "insert at each selected line", false, "insert_visual")
  map("x", config.mappings.append_visual, function()
    M.append_visual()
  end, "append at each selected line", false, "append_visual")
  for _, action in ipairs({
    "replace",
    "exchange",
    "multiply",
    "sort",
    "evaluate",
    "align",
    "titlecase",
  }) do
    local function start()
      return M.operator(action)
    end
    local function visual()
      require("editing_tools.operators").visual(action)
    end
    local function line()
      return M.operator(action) .. "_"
    end
    local plug = "<Plug>(EditingTools-" .. action .. ")"
    map("n", plug, start, action .. " motion", true)
    map("x", plug, visual, action .. " selection")
    map("n", "<Plug>(EditingTools-" .. action .. "-line)", line, action .. " lines", true)
    local prefix = config.mappings[action]
    if prefix and prefix ~= "" then
      -- Registers/counts reach the operator through its first-use callback.
      map("n", prefix, start, action .. " motion", true)
      map("x", prefix, visual, action .. " selection")
      map("n", prefix .. prefix:sub(-1), line, action .. " lines", true)
    end
  end
end

function M.apply(action, range, opts)
  return require("editing_tools.operators").apply(action, range, opts)
end

-- Inclusive one-based line range, matching Ex command ranges.
function M.titlecase(first, last, opts)
  local buf = opts and opts.buf or 0
  first = first or vim.api.nvim_win_get_cursor(0)[1]
  last = last or first
  local line = vim.api.nvim_buf_get_lines(buf, last - 1, last, true)[1]
  assert(line, "Titlecase range is outside the buffer")
  return M.apply(
    "titlecase",
    { start = { first - 1, 0 }, finish = { last - 1, #line }, mode = "line" },
    opts
  )
end

function M.operator(action, opts)
  return require("editing_tools.operators").start(action, opts)
end

function M.insert_visual()
  return require("editing_tools.multiedit").start("insert")
end

function M.append_visual()
  return require("editing_tools.multiedit").start("append")
end

function M.stop_multicursor()
  local multi = package.loaded["editing_tools.multiedit"]
  if multi then
    multi.stop()
  end
end

function M.cancel_exchange()
  local exchange = package.loaded["editing_tools.exchange"]
  if exchange then
    exchange.cancel()
  end
end

function M.align_lines(lines, opts)
  return require("editing_tools.align").lines(lines, opts)
end

function M.align(range, opts)
  return require("editing_tools.align").interactive(range, opts)
end

function M.command(args)
  local action = args.fargs[1]
  if action == "cancel" then
    M.cancel_exchange()
    M.stop_multicursor()
    local align = package.loaded["editing_tools.align"]
    if align then
      align.cancel()
    end
    return
  end
  local last = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
  local range = { start = { args.line1 - 1, 0 }, finish = { args.line2 - 1, #last }, mode = "line" }
  if action == "align" then
    M.align(
      range,
      { delimiter = args.fargs[2] or require("editing_tools.config").options.align.delimiter }
    )
  else
    M.apply(action, range)
  end
end

return M
