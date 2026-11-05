; Source: nvim-treesitter/nvim-treesitter-textobjects (5c7b0263797dfd1bd6202f2b219f3b53a80b2187).
; Apache-2.0; see THIRD_PARTY.md. Vendored query data, no upstream Lua runtime.
; assignment
(command
  name: (word) @_command
  argument: (word) @_varname @assignment.lhs @assignment.inner
  argument: (_)* @assignment.rhs
  (#not-lua-match? @_varname "[-].*")
  (#eq? @_command "set")) @assignment.outer

(command
  name: (word) @_name
  argument: (_)* @assignment.inner
  (#eq? @_name "set"))

; block
([
  (case_clause)
  (if_statement)
  (switch_statement)
  (else_clause)
  (for_statement)
  (while_statement)
]) @block.outer

; call
; call.inner doesn't work because it can't select *all* arguments
(command) @call.outer

; comment
; leave space after comment marker if there is one
((comment) @comment.inner @comment.outer
  (#offset! @comment.inner 0 2 0 0)
  (#lua-match? @comment.outer "# .*"))

; else remove everything accept comment marker
((comment) @comment.inner @comment.outer
  (#offset! @comment.inner 0 1 0 0))

; conditional
(if_statement
  (command) @conditional.inner) @conditional.outer

(switch_statement
  (_) @conditional.inner) @conditional.outer

; function
; Modified: capture all body siblings instead of offsetting into the final line.
(function_definition
  name: (_)
  "\n"
  [(_) "\n"]+ @function.inner
  "end") @function.outer

; loop
(for_statement
  (_) @loop.inner) @loop.outer

(while_statement
  condition: (command)
  (command) @loop.inner) @loop.outer

; number
[
  (integer)
  (float)
] @number.inner

; parameter
(command
  argument: (_) @parameter.outer)

; return
(return
  (_) @return.inner) @return.outer

; statement
(command) @statement.outer
