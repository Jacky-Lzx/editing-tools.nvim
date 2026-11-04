local M = {}
local owned = {}

local function map(mode, lhs, rhs, desc, expr)
  if not lhs or lhs == "" then
    return
  end
  vim.keymap.set(
    mode,
    lhs,
    rhs,
    { desc = "Editing: " .. desc, expr = expr or false, silent = true }
  )
  owned[#owned + 1] = { mode, lhs, rhs }
end

local function read_id()
  local ok, id = pcall(vim.fn.getcharstr)
  if not ok or id == "\27" or id == "\3" then
    return nil
  end
  return id
end

function M.setup(opts)
  local config = require("editing_tools.config").setup(opts)
  for _, item in ipairs(owned) do
    local current = vim.fn.maparg(item[2], item[1], false, true)
    if current.callback == item[3] or current.rhs == item[3] then
      pcall(vim.keymap.del, item[1], item[2])
    end
  end
  owned = {}
  for _, kind in ipairs({ "inside", "around" }) do
    for _, direction in ipairs({ "current", "next", "prev" }) do
      local name = kind .. (direction == "current" and "" or "_" .. direction)
      for _, mode in ipairs({ "o", "x" }) do
        map(mode, config.mappings[name], function()
          local id = read_id()
          if not id then
            return "<Esc>"
          end
          -- Native objects remain native, including user-defined word/sentence motions.
          local builtins = { w = true, W = true, s = true, p = true }
          if builtins[id] and direction == "current" then
            return (kind == "inside" and "i" or "a") .. id
          end
          local count = vim.v.count1
          return "<Cmd>lua require('editing_tools')._select("
            .. vim.inspect(id)
            .. ","
            .. vim.inspect(kind)
            .. ","
            .. vim.inspect(direction)
            .. ","
            .. count
            .. ")<CR>"
        end, name .. " text object", true)
      end
    end
  end
  for _, edge in ipairs({ "start", "end" }) do
    map("n", config.mappings["goto_" .. edge], function()
      local id = read_id()
      if not id then
        return
      end
      local range = M.find(id, "around", { count = vim.v.count1 })
      if range then
        vim.cmd.normal({ "m'", bang = true })
        local pos = edge == "start" and range.start or range.finish
        vim.api.nvim_win_set_cursor(0, { pos[1] + 1, pos[2] })
      end
    end, "go to object " .. edge)
  end
  require("editing_tools.operators").setup(config, map)
end

function M._select(id, kind, direction, count)
  local opts = { direction = direction, count = count }
  if vim.fn.mode():match("^[vV\22]") then
    opts.reference = require("editing_tools.range").visual()
  end
  local ok, selected = pcall(function()
    local range = M.find(id, kind, opts)
    if not range then
      return false
    end
    if require("editing_tools.range").equal(range.start, range.finish) then
      -- Let Vim handle empty native objects, including ci( and its redo record.
      local native = {
        b = "(",
        ["("] = "(",
        [")"] = "(",
        ["["] = "[",
        ["]"] = "[",
        ["{"] = "{",
        ["}"] = "}",
        ['"'] = '"',
        ["'"] = "'",
        ["`"] = "`",
      }
      if vim.fn.mode():sub(1, 2) == "no" and native[id] then
        vim.api.nvim_feedkeys((kind == "inside" and "i" or "a") .. native[id], "ni", false)
        return true
      end
      return false
    end
    require("editing_tools.range").select(range)
    return true
  end)
  if not ok or not selected then
    require("editing_tools.operators").abort()
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
    if not ok then
      vim.notify(selected, vim.log.levels.ERROR)
    end
  end
end

function M.find(id, kind, opts)
  return require("editing_tools.objects").find(id, kind, opts)
end
function M.select(id, kind, opts)
  return require("editing_tools.objects").select(id, kind, opts)
end

function M.apply(action, range, opts)
  return require("editing_tools.operators").apply(action, range, opts)
end

function M.operator(action, opts)
  return require("editing_tools.operators").start(action, opts)
end

function M.cancel_exchange()
  require("editing_tools.exchange").cancel()
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
    require("editing_tools.align").cancel()
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
