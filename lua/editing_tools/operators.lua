local M = {}
local R = require("editing_tools.range")
local state

function M.apply(action, range, opts)
  opts = opts or {}
  local buf = opts.buf or vim.api.nvim_get_current_buf()
  if buf ~= 0 and buf ~= vim.api.nvim_get_current_buf() then
    return vim.api.nvim_buf_call(buf, function()
      return M.apply(action, range, opts)
    end)
  end
  if action == "align" then
    return require("editing_tools.align").apply(range, opts, buf)
  end
  if action == "exchange" then
    return require("editing_tools.exchange").apply(range, buf)
  end
  local transform = require("editing_tools.transform")[action]
  assert(transform, "unknown editing action: " .. tostring(action))
  local old = R.get(range, buf)
  local new = transform(vim.deepcopy(old), range.mode or "char", opts)
  assert(type(new) == "table" and vim.islist(new), "transform must return a list of lines")
  for _, line in ipairs(new) do
    assert(
      type(line) == "string" and not line:find("\n", 1, true),
      "transform returned an invalid line"
    )
  end
  if vim.deep_equal(old, new) then
    return false
  end
  R.put(range, new, buf)
  return true
end

function M.start(action, opts)
  state = { action = action, opts = vim.deepcopy(opts or {}), fresh = true }
  state.opts.register = state.opts.register or vim.v.register
  vim.go.operatorfunc = "v:lua.require'editing_tools.operators'.dispatch"
  return "g@"
end

function M.dispatch(kind)
  if not state or state.cancelled then
    return
  end
  local current = state
  local range = current.visual_range or R.operator(kind)
  current.visual_range = nil
  local ok, err = pcall(function()
    if current.action == "align" then
      if current.fresh then
        current.fresh = false
        require("editing_tools.align").interactive(range, current.opts, function(confirmed)
          if confirmed then
            current.opts = confirmed
          else
            current.cancelled = true
          end
        end)
      elseif not current.cancelled then
        require("editing_tools.align").apply(range, current.opts)
      end
    else
      M.apply(current.action, range, current.opts)
    end
  end)
  if not ok then
    vim.notify("editing-tools: " .. tostring(err), vim.log.levels.WARN)
  end
end

function M.abort()
  if state then
    state.cancelled = true
  end
end

function M.visual(action, opts)
  local range = R.visual()
  local kind = range.mode == "line" and "V" or range.mode == "block" and "\22" or "v"
  -- Re-select with g@ so Vim records selection dimensions for dot-repeat.
  local keys = M.start(action, opts)
  state.visual_range = range
  vim.cmd.normal({ "\27", bang = true })
  vim.cmd.normal({ "gv" .. keys, bang = true })
  return kind
end

function M.setup(config, map)
  require("editing_tools.align").cancel()
  require("editing_tools.exchange").cancel()
  for _, action in ipairs({ "replace", "exchange", "multiply", "sort", "evaluate", "align" }) do
    local plug = "<Plug>(EditingTools-" .. action .. ")"
    map("n", plug, function()
      return M.start(action)
    end, action .. " motion", true)
    map("x", plug, function()
      M.visual(action)
    end, action .. " selection")
    local prefix = config.mappings[action]
    if prefix and prefix ~= "" then
      -- Mappings are callbacks so registers/counts reach the operator unchanged.
      map("n", prefix, function()
        return M.start(action)
      end, action .. " motion", true)
      map("x", prefix, function()
        M.visual(action)
      end, action .. " selection")
      map("n", prefix .. prefix:sub(-1), function()
        return M.start(action) .. "_"
      end, action .. " lines", true)
    end
  end
end

return M
