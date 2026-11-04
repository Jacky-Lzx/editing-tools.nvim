local M = {}

function M.snapshot(buf, pos, opts)
  local first = math.max(0, pos[1] - opts.lines)
  local last = math.min(vim.api.nvim_buf_line_count(buf), pos[1] + opts.lines + 1)
  local size = vim.api.nvim_buf_get_offset(buf, last) - vim.api.nvim_buf_get_offset(buf, first)
  if size > opts.max_bytes then
    return nil
  end
  local lines = vim.api.nvim_buf_get_lines(buf, first, last, true)
  local starts, offset = {}, 0
  for i, line in ipairs(lines) do
    starts[i], offset = offset, offset + #line + 1
  end
  local result = { text = table.concat(lines, "\n"), lines = lines, first = first, starts = starts }
  function result.position(byte)
    local lo, hi = 1, #starts
    while lo < hi do
      local mid = math.ceil((lo + hi) / 2)
      if starts[mid] <= byte then
        lo = mid
      else
        hi = mid - 1
      end
    end
    return { first + lo - 1, byte - starts[lo] }
  end
  function result.range(a, b, mode)
    return { start = result.position(a), finish = result.position(b), mode = mode or "char" }
  end
  return result
end

-- This lexical scanner deliberately handles ordinary strings and brackets only.
function M.pairs(text)
  local stack, pairs_found, quotes = {}, {}, {}
  local close = { ["("] = ")", ["["] = "]", ["{"] = "}" }
  local quote, quote_start, escaped
  for i = 1, #text do
    local ch = text:sub(i, i)
    if quote then
      if escaped then
        escaped = false
      elseif ch == "\\" then
        escaped = true
      elseif ch == quote then
        quotes[#quotes + 1] = { a = quote_start - 1, b = i, open = quote }
        quote = nil
      elseif ch == "\n" and quote ~= "`" then
        quote = nil
      end
    elseif ch == '"' or ch == "'" or ch == "`" then
      quote, quote_start, escaped = ch, i, false
    elseif close[ch] then
      stack[#stack + 1] = { a = i - 1, open = ch, close = close[ch] }
    elseif ch == ")" or ch == "]" or ch == "}" then
      local entry = stack[#stack]
      if entry and entry.close == ch then
        stack[#stack] = nil
        entry.b = i
        pairs_found[#pairs_found + 1] = entry
      else
        stack = {}
      end
    end
  end
  return pairs_found, quotes
end

return M
