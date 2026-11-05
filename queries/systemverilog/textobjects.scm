; Source: nvim-treesitter/nvim-treesitter-textobjects (5c7b0263797dfd1bd6202f2b219f3b53a80b2187).
; Apache-2.0; see THIRD_PARTY.md. Vendored query data, no upstream Lua runtime.
(function_declaration
  (function_body_declaration
    (tf_port_list)
    .
    _+ @function.inner
    .
    "endfunction")) @function.outer

(task_declaration
  (task_body_declaration
    (tf_port_list)
    .
    _+ @function.inner
    .
    "endtask")) @function.outer

[
  (seq_block)
  (generate_block)
] @block.outer

(seq_block
  "begin"
  (simple_identifier)?
  .
  _+ @block.inner
  .
  "end")

(generate_block
  "begin"
  (simple_identifier)?
  .
  _+ @block.inner
  .
  "end")

[
  (one_line_comment)
  (block_comment)
] @comment.outer
