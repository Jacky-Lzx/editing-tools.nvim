local M = {}
local api = vim.api
local R = require("editing_tools.range")
local ns = api.nvim_create_namespace("editing_tools.align")
local active

local function split_lines(lines, opts)
  local result, stack, quote, escaped = {}, {}, nil, false
  local closing = { ["("] = ")", ["["] = "]", ["{"] = "}" }
  for row, line in ipairs(lines) do
    local fields, begin, i = {}, 1, 1
    local matches = {}
    local from, to
    if opts.preset == "equals" then
      from, to = line:find("%p*=+[<>~]*")
    end
    while i <= #line do
      local char = line:sub(i, i)
      if opts.preset == "equals" then
        if from and from < i then
          from, to = line:find("%p*=+[<>~]*", i)
        end
      else
        from, to = nil, nil
        if line:sub(i, i + #opts.delimiter - 1) == opts.delimiter then
          from, to = i, i + #opts.delimiter - 1
        end
      end
      if (not opts.outside or not quote and #stack == 0) and from == i then
        matches[#matches + 1] = { from, to }
        i = to + 1
      else
        if quote then
          if escaped then
            escaped = false
          elseif char == "\\" then
            escaped = true
          elseif char == quote then
            quote = nil
          end
        elseif char == '"' or char == "'" or char == "`" then
          quote = char
        elseif closing[char] then
          stack[#stack + 1] = closing[char]
        elseif stack[#stack] == char then
          table.remove(stack)
        end
        i = i + 1
      end
    end
    if quote ~= "`" then
      quote = nil
    end
    escaped = false
    if opts.occurrence == "first" and #matches > 0 then
      matches = { matches[1] }
    elseif opts.occurrence == "last" and #matches > 0 then
      matches = { matches[#matches] }
    end
    for _, at in ipairs(matches) do
      fields[#fields + 1] = line:sub(begin, at[1] - 1)
      if opts.preset == "equals" then
        fields[#fields + 1] = line:sub(at[1], at[2])
      end
      begin = at[2] + 1
    end
    if opts.preset ~= "equals" or begin <= #line or #fields == 0 then
      fields[#fields + 1] = line:sub(begin)
    end
    if opts.trim and (#fields > 1 or opts.preset == "equals") then
      for j, value in ipairs(fields) do
        if j == 1 then
          fields[j] = value:gsub("%s+$", "")
        else
          fields[j] = value:match("^%s*(.-)%s*$")
        end
      end
    end
    result[row] = fields
  end
  return result
end

local function expand_tabs(text, column, tabstop)
  local output = {}
  for _, char in ipairs(vim.fn.split(text, "\\zs")) do
    if char == "\t" then
      char = string.rep(" ", tabstop - column % tabstop)
    end
    output[#output + 1] = char
    column = column + vim.fn.strdisplaywidth(char, column)
  end
  return table.concat(output)
end

function M.lines(lines, opts)
  opts = vim.tbl_extend("force", require("editing_tools.config").options.align, opts or {})
  assert(
    type(opts.delimiter) == "string"
      and opts.delimiter ~= ""
      and not opts.delimiter:find("\n", 1, true),
    "delimiter must be a nonempty single-line string"
  )
  assert(vim.tbl_contains({ "first", "last", "all" }, opts.occurrence), "invalid occurrence")
  assert(vim.tbl_contains({ "left", "right" }, opts.justify), "invalid justification")
  assert(opts.preset == nil or opts.preset == "equals", "invalid alignment preset")
  assert(
    type(opts.padding) == "number"
      and opts.padding >= 0
      and opts.padding % 1 == 0
      and opts.padding <= 100,
    "padding must be between 0 and 100"
  )
  local fields = split_lines(lines, opts)
  local equals = opts.preset == "equals"
  local first_is_indent = equals
  for _, row in ipairs(fields) do
    first_is_indent = first_is_indent and row[1]:match("^%s*$") ~= nil
  end
  local output, columns, maximum = {}, {}, 0
  for i, row in ipairs(fields) do
    output[i], columns[i] = "", opts.columns and opts.columns[i] or opts.start_column or 0
    maximum = math.max(maximum, #row)
  end
  for col = 1, maximum do
    local width, values = 0, {}
    for i, row in ipairs(fields) do
      if row[col] then
        values[i] = expand_tabs(row[col], columns[i], opts.tabstop or vim.bo.tabstop)
        if col < #row or equals and opts.justify == "right" then
          local offset = equals and col == 1 and columns[i] or 0
          width = math.max(width, vim.fn.strdisplaywidth(values[i], columns[i]) + offset)
        end
      end
    end
    for i, row in ipairs(fields) do
      if row[col] then
        local value = values[i]
        if col < #row or equals and opts.justify == "right" and not value:match("^%s*$") then
          local offset = equals and col == 1 and columns[i] or 0
          local padding =
            string.rep(" ", width - vim.fn.strdisplaywidth(value, columns[i]) - offset)
          value = opts.justify == "right" and padding .. value or value .. padding
        end
        if col < #row then
          if equals then
            value = value .. string.rep(" ", col == 1 and first_is_indent and 0 or opts.padding)
          else
            value = value
              .. string.rep(" ", opts.padding)
              .. opts.delimiter
              .. string.rep(" ", opts.padding)
          end
        end
        output[i] = output[i] .. value
        columns[i] = columns[i] + vim.fn.strdisplaywidth(value, columns[i])
      end
    end
  end
  -- Unmatched lines retain their bytes, including tabs and trailing spaces.
  for i, row in ipairs(fields) do
    if #row == 1 and not equals then
      output[i] = lines[i]
    end
  end
  return output
end

local function options_for_range(range, opts, buf)
  opts = vim.deepcopy(opts or {})
  opts.columns = {}
  local lines = api.nvim_buf_get_lines(buf, range.start[1], range.finish[1] + 1, true)
  for i, line in ipairs(lines) do
    local col = range.mode == "block" and range.segments[i].start or i == 1 and range.start[2] or 0
    opts.columns[i] = vim.fn.strdisplaywidth(line:sub(1, col))
  end
  opts.tabstop = vim.bo[buf].tabstop
  return opts
end

function M.apply(range, opts, buf)
  buf = buf or api.nvim_get_current_buf()
  local old = R.get(range, buf)
  local new = M.lines(old, options_for_range(range, opts, buf))
  if vim.deep_equal(old, new) then
    return false
  end
  R.put(range, new, buf)
  return true
end

function M.cancel()
  if active then
    active.finish(false)
  end
end

function M.is_active()
  return active ~= nil
end

function M.interactive(range, opts, callback)
  M.cancel()
  local buf, win = api.nvim_get_current_buf(), api.nvim_get_current_win()
  local changedtick = api.nvim_buf_get_changedtick(buf)
  local original = R.get(range, buf)
  local options = vim.tbl_extend("force", require("editing_tools.config").options.align, opts or {})
  local session = { range = range, buf = buf, win = win }
  active = session
  local preview_buf = api.nvim_create_buf(false, true)
  vim.bo[preview_buf].bufhidden = "wipe"
  local width = math.max(1, math.min(90, vim.o.columns - 4))
  local preview_win = api.nvim_open_win(preview_buf, false, {
    relative = "editor",
    row = math.max(0, vim.o.lines - 5),
    col = 1,
    width = width,
    height = 2,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 80,
  })
  local group = api.nvim_create_augroup("editing_tools_align_session", { clear = true })
  local old_maps, installed = {}, {}
  local function binding(lhs, rhs)
    old_maps[lhs] = vim.fn.maparg(lhs, "n", false, true)
    vim.keymap.set(
      "n",
      lhs,
      rhs,
      { buffer = buf, nowait = true, silent = true, desc = "Editing alignment preview" }
    )
    installed[lhs] = rhs
  end
  local function render()
    if active ~= session then
      return
    end
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local ok, lines = pcall(M.lines, original, options_for_range(range, options, buf))
    if not ok then
      return
    end
    for i, line in ipairs(lines) do
      local row = range.start[1] + i - 1
      local full = api.nvim_buf_get_lines(buf, row, row + 1, true)[1]
      local col = range.mode == "block" and range.segments[i].start
        or i == 1 and range.start[2]
        or 0
      local finish = range.mode == "block" and range.segments[i].finish
        or i == #lines and range.finish[2]
        or #full
      if range.mode == "line" then
        finish = #full
      end
      local prefix = range.mode == "block" and range.segments[i].prefix or ""
      local suffix = range.mode == "block" and range.segments[i].suffix or ""
      local replacement = full:sub(1, col) .. prefix .. line .. suffix .. full:sub(finish + 1)
      local padding =
        math.max(0, vim.fn.strdisplaywidth(full) - vim.fn.strdisplaywidth(replacement))
      api.nvim_buf_set_extmark(buf, ns, row, 0, {
        virt_text = { { replacement .. string.rep(" ", padding), "Normal" } },
        virt_text_pos = "overlay",
        priority = 200,
      })
    end
    api.nvim_buf_set_lines(preview_buf, 0, -1, false, {
      "Align "
        .. vim.inspect(options.delimiter)
        .. (options.preset == "equals" and " operators" or "")
        .. " | "
        .. options.occurrence
        .. " | "
        .. options.justify
        .. " | padding "
        .. options.padding
        .. (options.outside and " | outside brackets/quotes" or " | all positions"),
      "Enter apply · Esc cancel · = operators · d delimiter · o occurrence · j justify · +/- padding · b brackets · t trim",
    })
  end
  function session.finish(commit)
    if active ~= session then
      return
    end
    active = nil
    pcall(api.nvim_del_augroup_by_id, group)
    if api.nvim_buf_is_valid(buf) then
      api.nvim_buf_clear_namespace(buf, ns, 0, -1)
      api.nvim_buf_call(buf, function()
        for lhs, fn in pairs(installed) do
          local current = vim.fn.maparg(lhs, "n", false, true)
          if current.callback == fn then
            pcall(vim.keymap.del, "n", lhs, { buffer = buf })
            if old_maps[lhs].buffer == 1 then
              vim.fn.mapset("n", false, old_maps[lhs])
            end
          end
        end
      end)
    end
    if api.nvim_win_is_valid(preview_win) then
      api.nvim_win_close(preview_win, true)
    end
    local valid = api.nvim_buf_is_valid(buf)
      and api.nvim_get_current_buf() == buf
      and api.nvim_buf_get_changedtick(buf) == changedtick
    local confirmed
    if commit and valid then
      local ok, err = pcall(M.apply, range, options, buf)
      if ok then
        confirmed = vim.deepcopy(options)
      else
        vim.notify("editing-tools: " .. tostring(err), vim.log.levels.WARN)
      end
    elseif commit then
      vim.notify(
        "editing-tools: alignment cancelled because the buffer changed",
        vim.log.levels.WARN
      )
    end
    if callback then
      callback(confirmed)
    end
  end
  binding("<CR>", function()
    session.finish(true)
  end)
  binding("<Esc>", function()
    session.finish(false)
  end)
  binding("<C-c>", function()
    session.finish(false)
  end)
  binding("=", function()
    -- Match mini.align's '=' modifier: align operator tokens as columns and
    -- split every match, including those inside strings and brackets.
    options.preset = "equals"
    options.delimiter, options.occurrence = "=", "all"
    options.trim, options.padding, options.outside = true, 1, false
    render()
  end)
  binding("d", function()
    vim.ui.input({ prompt = "Align delimiter: ", default = options.delimiter }, function(value)
      if active == session and value and value ~= "" and not value:find("\n", 1, true) then
        options.delimiter = value
        options.preset = nil
        render()
      end
    end)
  end)
  binding("o", function()
    local next_value = { all = "first", first = "last", last = "all" }
    options.occurrence = next_value[options.occurrence]
    render()
  end)
  binding("j", function()
    options.justify = options.justify == "left" and "right" or "left"
    render()
  end)
  binding("+", function()
    options.padding = math.min(100, options.padding + 1)
    render()
  end)
  binding("-", function()
    options.padding = math.max(0, options.padding - 1)
    render()
  end)
  binding("b", function()
    options.outside = not options.outside
    render()
  end)
  binding("t", function()
    options.trim = not options.trim
    render()
  end)
  api.nvim_create_autocmd(
    { "BufLeave", "BufWipeout", "InsertEnter", "TextChanged", "TextChangedI" },
    {
      group = group,
      buffer = buf,
      callback = function(event)
        if
          (event.event == "TextChanged" or event.event == "TextChangedI")
          and api.nvim_buf_get_changedtick(buf) == changedtick
        then
          return
        end
        session.finish(false)
      end,
    }
  )
  api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function()
      if api.nvim_get_current_win() == win then
        session.finish(false)
      end
    end,
  })
  render()
end

return M
