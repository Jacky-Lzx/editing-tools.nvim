; Source: nvim-treesitter/nvim-treesitter-textobjects (5c7b0263797dfd1bd6202f2b219f3b53a80b2187).
; Apache-2.0; see THIRD_PARTY.md. Vendored query data, no upstream Lua runtime.
(class_declaration
  body: (class_body
    .
    "{"
    _+ @class.inner
    "}")) @class.outer

(class_declaration
  body: (enum_class_body
    .
    "{"
    _+ @class.inner
    "}")) @class.outer

(function_declaration
  body: (function_body
    .
    "{"
    _+ @function.inner
    "}")) @function.outer

(lambda_literal
  ("{"
    _+ @function.inner
    "}")) @function.outer

(call_suffix
  (value_arguments
    .
    "("
    _+ @call.inner
    ")")) @call.outer

(value_argument
  value: (_) @parameter.inner) @parameter.outer

(comment) @comment.outer

(multiline_comment) @comment.outer
