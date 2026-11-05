; Source: nvim-treesitter/nvim-treesitter-textobjects (5c7b0263797dfd1bd6202f2b219f3b53a80b2187).
; Apache-2.0; see THIRD_PARTY.md. Vendored query data, no upstream Lua runtime.
(function_definition
  body: (_) @function.inner) @function.outer

(constructor_definition
  body: (_) @function.inner) @function.outer

(class_definition
  body: (_) @class.inner) @class.outer

(if_statement
  body: (_) @conditional.inner) @conditional.outer

(if_statement
  alternative: (_
    (_) @conditional.inner)?) @conditional.outer

(if_statement
  condition: (_) @conditional.inner)

[
  (for_statement)
  (while_statement)
] @loop.outer

(while_statement
  body: (_) @loop.inner)

(for_statement
  body: (_) @loop.inner)

(comment) @comment.outer

(parameters
  "," @parameter.outer
  .
  (_) @parameter.inner @parameter.outer)

(parameters
  .
  (_) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)

(arguments
  "," @parameter.outer
  .
  (_) @parameter.inner @parameter.outer)

(arguments
  .
  (_) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)

(array
  "," @parameter.outer
  .
  (_) @parameter.inner @parameter.outer)

(array
  .
  (_) @parameter.inner @parameter.outer
  .
  ","? @parameter.outer)
