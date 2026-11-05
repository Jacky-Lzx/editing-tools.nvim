; Source: nvim-treesitter/nvim-treesitter-textobjects (5c7b0263797dfd1bd6202f2b219f3b53a80b2187).
; Apache-2.0; see THIRD_PARTY.md. Vendored query data, no upstream Lua runtime.
(atx_heading
  heading_content: (_) @class.inner) @class.outer

(setext_heading
  heading_content: (_) @class.inner) @class.outer

(thematic_break) @class.outer

(fenced_code_block
  (code_fence_content) @block.inner) @block.outer

[
  (paragraph)
  (list)
] @block.outer
