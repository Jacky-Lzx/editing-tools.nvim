local M = {}
local api = vim.api
local ranges = api.nvim_create_namespace("editing_tools.multiedit.ranges")
local cursors = api.nvim_create_namespace("editing_tools.multiedit.cursors")
local active, attached = nil, {}
local function position(state, id)
  local mark = api.nvim_buf_get_extmark_by_id(state.buf, ranges, id, { details = true })
  assert(#mark > 0 and not mark[3].invalid, "insertion range was removed")
  return { mark[1], mark[2], mark[3].end_row, mark[3].end_col }
end
local function text(state, pos)
  return api.nvim_buf_get_text(state.buf, pos[1], pos[2], pos[3], pos[4], {})
end
local function check(state, item, pos)
  local first = api.nvim_buf_get_lines(state.buf, pos[1], pos[1] + 1, true)[1]
  local last = api.nvim_buf_get_lines(state.buf, pos[3], pos[3] + 1, true)[1]
  assert(
    first:sub(1, pos[2]) == item.prefix and last:sub(pos[4] + 1) == item.suffix,
    "edit left the insertion ranges"
  )
end
local function draw(state)
  api.nvim_buf_clear_namespace(state.buf, cursors, 0, -1)
  local primary = position(state, state.primary.id)
  local caret = api.nvim_win_get_cursor(state.win)
  local less = require("editing_tools.range").less
  local point = { caret[1] - 1, caret[2] }
  if less(point, { primary[1], primary[2] }) or less({ primary[3], primary[4] }, point) then
    return
  end
  local relative_row = caret[1] - 1 - primary[1]
  local relative_col = caret[2] - (relative_row == 0 and primary[2] or 0)
  for _, item in ipairs(state.items) do
    if item ~= state.primary then
      local pos = position(state, item.id)
      local row = pos[1] + relative_row
      local line = api.nvim_buf_get_lines(state.buf, row, row + 1, true)[1]
      local col = math.max(0, math.min(#line, relative_col + (relative_row == 0 and pos[2] or 0)))
      if col < #line then
        api.nvim_buf_set_extmark(state.buf, cursors, row, col, {
          end_col = require("editing_tools.range").char_end(line, col),
          hl_group = "Cursor",
          priority = 250,
        })
      else
        api.nvim_buf_set_extmark(
          state.buf,
          cursors,
          row,
          col,
          { virt_text = { { " ", "Cursor" } }, virt_text_pos = "overlay", priority = 250 }
        )
      end
    end
  end
end
local function flush(state)
  if state ~= active or state.applying or not api.nvim_buf_is_loaded(state.buf) then
    return
  end
  local main = position(state, state.primary.id)
  local value = text(state, main)
  local bytes = math.max(0, #value - 1)
  for _, line in ipairs(value) do
    bytes = bytes + #line
  end
  assert(
    bytes * #state.items + state.original_bytes <= 8 * 1024 * 1024,
    "mirrored insertion exceeds 8 MiB"
  )
  local targets, all = {}, {}
  for _, item in ipairs(state.items) do
    local pos = position(state, item.id)
    check(state, item, pos)
    all[#all + 1] = pos
    if item ~= state.primary then
      assert(
        vim.deep_equal(text(state, pos), state.last),
        "another edit changed a secondary insertion"
      )
      targets[#targets + 1] = { item = item, pos = pos }
    end
  end
  table.sort(all, function(a, b)
    return a[1] == b[1] and a[2] < b[2] or a[1] < b[1]
  end)
  for i = 2, #all do
    assert(
      require("editing_tools.range").less(
        { all[i - 1][3], all[i - 1][4] },
        { all[i][1], all[i][2] }
      ),
      "insertion ranges overlapped"
    )
  end
  if not vim.deep_equal(value, state.last) then
    assert(vim.bo[state.buf].modifiable, "buffer is no longer modifiable")
    local caret = api.nvim_win_get_cursor(state.win)
    local cursor =
      api.nvim_buf_set_extmark(state.buf, ranges, caret[1] - 1, caret[2], { right_gravity = true })
    table.sort(targets, function(a, b)
      return a.pos[1] > b.pos[1]
    end)
    state.applying = true
    local ok, err = pcall(function()
      for _, target in ipairs(targets) do
        local pos = position(state, target.item.id)
        vim.cmd("undojoin")
        api.nvim_buf_set_text(state.buf, pos[1], pos[2], pos[3], pos[4], value)
      end
    end)
    state.applying = false
    local now = api.nvim_buf_get_extmark_by_id(state.buf, ranges, cursor, {})
    api.nvim_buf_del_extmark(state.buf, ranges, cursor)
    if #now > 0 and api.nvim_win_is_valid(state.win) then
      api.nvim_win_set_cursor(state.win, { now[1] + 1, now[2] })
    end
    assert(ok, err)
    state.last = vim.deepcopy(value)
    state.changed = true
  end
  draw(state)
end
function M.stop(event)
  local state = active
  if not state then
    return
  end
  local disposing = type(event) == "table"
    and (event.event == "BufWipeout" or event.event == "VimLeavePre")
  local ok, err = true, nil
  if not disposing then
    ok, err = pcall(flush, state)
  end
  active = nil
  if state.group then
    api.nvim_del_augroup_by_id(state.group)
  end
  if api.nvim_buf_is_valid(state.buf) then
    api.nvim_buf_clear_namespace(state.buf, ranges, 0, -1)
    api.nvim_buf_clear_namespace(state.buf, cursors, 0, -1)
    if
      not disposing
      and api.nvim_buf_is_loaded(state.buf)
      and state.prepared
      and not state.changed
      and api.nvim_buf_get_changedtick(state.buf) == state.prepared_tick
    then
      api.nvim_buf_call(state.buf, function()
        vim.cmd("silent undo")
      end)
    end
  end
  if not ok then
    vim.notify(
      "Multi-insert stopped: " .. tostring(err):gsub("^.-:%d+:%s*", ""),
      vim.log.levels.WARN
    )
  end
end
function M.is_active()
  return active ~= nil
end
local function schedule(state)
  if state.queued or state.applying then
    return
  end
  state.queued = true
  vim.schedule(function()
    state.queued = false
    if active == state then
      local ok, err = pcall(flush, state)
      if not ok then
        M.stop()
      end
    end
  end)
end
local function byte_at_cell(line, target, append)
  local col, cell = 0, 0
  while col < #line do
    local finish = vim.fn.byteidx(line, vim.fn.charidx(line, col) + 1)
    if finish < 0 then
      finish = #line
    end
    local char = line:sub(col + 1, finish)
    local width = vim.fn.strdisplaywidth(char, cell)
    if target <= cell then
      return line, col
    end
    if target < cell + width then
      if char == "\t" then
        return line:sub(1, col) .. string.rep(" ", width) .. line:sub(finish + 1),
          col + target - cell
      end
      return line, append and finish or col
    end
    col, cell = finish, cell + width
  end
  local padding = math.max(0, target - cell)
  return line .. string.rep(" ", padding), #line + padding
end
function M.start(action)
  assert(action == "insert" or action == "append", "expected insert or append")
  M.stop()
  local mode = vim.fn.mode()
  assert(mode:match("^[vV\22]"), "multi-insert requires a Visual selection")
  assert(vim.bo.modifiable and vim.bo.buftype == "", "expected a modifiable file buffer")
  local selection = assert(require("editing_tools.range").visual())
  local first, last = selection.start[1], selection.finish[1]
  assert(last - first < 1000, "multi-insert supports at most 1000 lines")
  local selected_row = api.nvim_win_get_cursor(0)[1] - 1
  selected_row = math.max(first, math.min(last, selected_row))
  local original = api.nvim_buf_get_lines(0, first, last + 1, true)
  local lines, columns = vim.deepcopy(original), {}
  local total = 0
  local goal
  if mode == "\22" and not (action == "append" and vim.fn.getcurpos()[5] >= 2147483647) then
    local a, b = vim.fn.virtcol("v", true), vim.fn.virtcol(".", true)
    local left = math.min(a[1], b[1]) - 1
    local width = 0
    for _, value in ipairs(selection.text or {}) do
      width = math.max(width, vim.fn.strdisplaywidth(value, left))
    end
    goal = action == "insert" and left or left + width
    assert(goal <= 1024 * 1024, "block column exceeds 1 MiB")
  end
  for i, line in ipairs(lines) do
    if goal then
      lines[i], columns[i] = byte_at_cell(line, goal, action == "append")
    else
      columns[i] = action == "append" and #line or (line:find("%S") or 1) - 1
    end
    total = total + #lines[i]
    assert(total <= 1024 * 1024, "multi-insert selection exceeds 1 MiB")
  end
  vim.cmd.normal({ "\27", bang = true })
  local prepared = not vim.deep_equal(lines, original)
  if prepared then
    api.nvim_buf_set_lines(0, first, last + 1, true, lines)
  end
  local state = {
    buf = api.nvim_get_current_buf(),
    win = api.nvim_get_current_win(),
    items = {},
    last = { "" },
    original_bytes = total,
    prepared = prepared,
    prepared_tick = api.nvim_buf_get_changedtick(0),
  }
  active = state
  for i, line in ipairs(lines) do
    local col, row = columns[i], first + i - 1
    local item = { prefix = line:sub(1, col), suffix = line:sub(col + 1) }
    item.id = api.nvim_buf_set_extmark(
      0,
      ranges,
      row,
      col,
      { end_row = row, end_col = col, right_gravity = false, end_right_gravity = true }
    )
    state.items[#state.items + 1] = item
    if row == selected_row then
      state.primary = item
    end
  end
  if not attached[state.buf] then
    attached[state.buf] = true
    api.nvim_buf_attach(state.buf, false, {
      on_lines = function(_, buf)
        if active and active.buf == buf then
          schedule(active)
        else
          attached[buf] = nil
          return true
        end
      end,
      on_detach = function(_, buf)
        attached[buf] = nil
        if active and active.buf == buf then
          M.stop()
        end
      end,
    })
  end
  local pos = position(state, state.primary.id)
  local line = api.nvim_buf_get_lines(0, pos[1], pos[1] + 1, true)[1]
  local key = "i"
  local col = pos[2]
  if col == #line and #line > 0 then
    col = vim.fn.byteidx(line, math.max(0, vim.fn.strchars(line, true) - 1))
    key = "a"
  end
  api.nvim_win_set_cursor(0, { pos[1] + 1, col })
  state.group = api.nvim_create_augroup("EditingToolsMultiInsert", { clear = true })
  api.nvim_create_autocmd("InsertEnter", {
    group = state.group,
    buffer = state.buf,
    callback = function()
      state.started = true
      schedule(state)
    end,
  })
  api.nvim_create_autocmd("ModeChanged", {
    group = state.group,
    callback = function()
      if state.started and not vim.fn.mode():match("^[iR]") then
        M.stop()
      end
    end,
  })
  api.nvim_create_autocmd(
    { "InsertLeave", "BufLeave", "WinLeave", "BufWipeout", "VimLeavePre" },
    { group = state.group, callback = M.stop }
  )
  api.nvim_create_autocmd("CursorMovedI", {
    group = state.group,
    buffer = state.buf,
    callback = function()
      local main = position(state, state.primary.id)
      local cursor = api.nvim_win_get_cursor(state.win)
      local point, less = { cursor[1] - 1, cursor[2] }, require("editing_tools.range").less
      if less(point, { main[1], main[2] }) or less({ main[3], main[4] }, point) then
        M.stop()
      else
        schedule(state)
      end
    end,
  })
  if prepared then
    vim.cmd("undojoin")
  end
  -- Prepend native insert so already queued user input retains its normal mappings.
  api.nvim_feedkeys(key, "in", false)
  return state
end
return M
