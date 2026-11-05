; Source: nvim-treesitter/nvim-treesitter-textobjects (5c7b0263797dfd1bd6202f2b219f3b53a80b2187).
; Apache-2.0; see THIRD_PARTY.md. Vendored query data, no upstream Lua runtime.
; named function
(binding
  (function_expression)) @function.outer

; anonymous function
(function_expression
  (_) ; argument
  (_) @function.inner) @function.outer

(function_expression
  (formals
    (formal) @parameter.inner))

(function_expression
  (_) @parameter.outer
  (_))

(comment) @comment.outer

(if_expression
  (_) @conditional.inner) @conditional.outer

[
  (integer_expression)
  (float_expression)
] @number.inner
