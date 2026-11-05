; Source: nvim-treesitter/nvim-treesitter-textobjects (5c7b0263797dfd1bd6202f2b219f3b53a80b2187).
; Apache-2.0; see THIRD_PARTY.md. Vendored query data, no upstream Lua runtime.
(function_def) @function.outer

(function_def
  .
  (function_command)
  _+ @function.inner
  (endfunction_command) .)

(if_condition) @conditional.outer

(if_condition
  .
  (if_command)
  _+ @conditional.inner
  (endif_command) .)

(foreach_loop) @loop.outer

(foreach_loop
  .
  (foreach_command)
  _+ @loop.inner
  (endforeach_command) .)

(normal_command) @call.outer

(normal_command
  "("
  _+ @call.inner
  ")")

(line_comment) @comment.outer
