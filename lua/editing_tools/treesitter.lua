local M = {}
local Range = require("editing_tools.range")

function M.collect(ctx, spec)
  local captures = spec[ctx.kind]
  if type(captures) == "string" then
    captures = { captures }
  end
  if not captures then
    return {}
  end
  local wanted = {}
  for _, name in ipairs(captures) do
    wanted[name:gsub("^@", "")] = true
  end
  local ok, parser = pcall(vim.treesitter.get_parser, ctx.buf, nil, { error = false })
  if not ok or not parser then
    return {}
  end
  local result = {}
  local success = pcall(function()
    parser:parse({ ctx.first, ctx.last })
    parser:for_each_tree(function(tree, language_tree)
      local query = vim.treesitter.query.get(language_tree:lang(), "textobjects")
      if not query then
        return
      end
      for _, match, metadata in query:iter_matches(tree:root(), ctx.buf, ctx.first, ctx.last) do
        for id, nodes in pairs(match) do
          if wanted[query.captures[id]] then
            local first, last
            -- Quantified captures describe one object spanning sibling nodes.
            for _, node in ipairs(nodes) do
              local native = vim.treesitter.get_range(node, ctx.buf, metadata[id])
              local start, finish = { native[1], native[2] }, { native[4], native[5] }
              if not first or Range.less(start, first) then
                first = start
              end
              if not last or Range.less(last, finish) then
                last = finish
              end
            end
            local a, b, c, d = first[1], first[2], last[1], last[2]
            -- Some grammars include a final newline in outer nodes.
            if d == 0 and c >= vim.api.nvim_buf_line_count(ctx.buf) then
              c = c - 1
              d = #vim.api.nvim_buf_get_lines(ctx.buf, c, c + 1, true)[1]
            end
            result[#result + 1] = { start = { a, b }, finish = { c, d }, mode = "char" }
          end
        end
      end
    end)
  end)
  return success and result or {}
end

return M
