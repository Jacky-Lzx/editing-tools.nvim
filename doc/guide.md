# Workflow and integration guide

[Quick start](../README.md) · [Complete reference](editing-tools.txt)

Configuration defaults and API contracts are maintained in the help reference.
The examples here illustrate particular workflows.

## Operators

| Mapping | Action | Line shortcut |
| --- | --- | --- |
| `cr{motion}` | Replace from a register | `crr` |
| `gx{motion}` | Exchange two selections | `gxx` |
| `gm{motion}` | Duplicate selection | `gmm` |
| `gs{motion}` | Sort lines, comma fields, or whitespace tokens | `gss` |
| `g={motion}` | Evaluate numeric arithmetic | `g==` |
| `ga{motion}` | Preview alignment | `gaa` |

All operators also accept Visual selections. Counts control motion extent:
`3gss` sorts three lines, `2gmm` duplicates two lines. `.` repeats the last
operator with its motion or Visual dimensions. The line shortcut takes priority
over the same key sequence interpreted as an operator plus text object; use
Visual selection if those sequences overlap.

`"acriw` replaces a word with register `a`; `cr` uses the unnamed register.
Replacement preserves all registers. Character and line selections accept
multiline contents; block replacements accept one repeated row or a register
whose height matches the selection. The expression register is unsupported.

Exchange highlights the first selection and applies on the second. Unrelated
edits can move the first selection; changes within it, overlaps, mixed selection
modes, and block exchange are rejected. Cross-buffer exchange is supported;
each buffer keeps its own undo history. `:EditingTools cancel` clears a pending
exchange or alignment.

Arithmetic evaluation accepts numbers and `+ - * / % ^ ( )` only, with Lua's
arithmetic semantics. It does not execute buffer text as unrestricted Lua.
Programmatic callers can supply an explicit `evaluator` callback.

## Alignment

`gaip` previews a paragraph; `3gaa` previews three lines. Preview uses virtual
text, leaving the buffer and undo history untouched. Enter applies; Esc or Ctrl-C
cancels. Leaving the buffer/window, entering Insert mode, or changing the source
also cancels. Confirmed settings are reused by `.` without opening another preview.

While previewing: `d` prompts for a literal delimiter, `o` cycles first/last/all
occurrences, `j` toggles left/right justification, `+` / `-` adjust padding, `b`
toggles bracket/quote filtering, and `t` toggles trimming. Temporary buffer mappings
are restored on exit.

For the previous mini.align workflow, select text and type `ga=`, or use
`gaip=` / `3gaa=`. The `=` modifier previews alignment of complete operators such
as `=`, `<=`, `==`, `+=` and `=>`, with separate aligned operator and value columns.
It trims whitespace, uses single-space padding and includes matches inside quotes
and brackets, as mini.align does. Enter applies; Esc cancels. `d` switches back to
literal-delimiter alignment.

Defaults align `=` with one space on each side, preserving indentation and lines
without a delimiter. Multicharacter delimiters, Unicode display widths and Tab
columns are supported. Bracket depth carries across lines. Filtering recognizes
ordinary quoted strings and brackets; it does not parse comments or specialized
language literals. The selection must include the opening bracket to establish
its nesting context.

## Insert at selected lines

Visual `mI` starts an insertion at each selected line's first nonblank character;
`mA` starts at each line's end. A block selection uses its left/right screen
column instead. The active Visual endpoint remains the native editing cursor.
Secondary cursors follow typed text live, including Unicode, native register
inserts, pair mappings, completion replacements and newlines. Cursor highlights
use the current theme's `Cursor` group.

Escape / Ctrl-C finishes the insert session and removes its markers. A buffer or
window switch also finishes it. Edits share the primary cursor's native undo
block, including block padding/tab expansion; explicit native undo breaks remain
in effect. An empty prepared block session restores its source on cancellation.
Wide characters are never split, and combining marks remain attached.

This is an insertion-session workflow, not a general Normal-mode multi-cursor
engine. Stay within the inserted span when editing; leaving it finishes the
session. An external edit to a target's surrounding text or secondary inserted
span stops synchronization rather than overwriting that edit. Selections are
bounded to 1000 lines and 1 MiB; mirrored insertion data is capped at 8 MiB. Insert mappings, completion and snippet engines
retain their normal key handling. Dot repeat follows native primary-cursor input.

```lua
local editing = require("editing_tools")
editing.insert_visual() -- called while in Visual mode
-- editing.append_visual()
editing.stop_multicursor()
-- Choose the calling keys in your own configuration.
```

`python3 tests/tui.py multiedit_tui.lua` verifies real input and intermediate
buffer/cursor states, native undo/redo, tabs, padding, Unicode, pair integration,
Control-C and buffer switches. It is included in `sh tests/run.sh`.

## Validation

```sh
sh tests/run.sh
python3 tests/tui.py
stylua --check lua plugin tests
```

Object/query tests live in motion-tools.nvim. Editing tests use the sibling
motion-tools.nvim checkout; set `EDITING_TOOLS_MOTION_DIR` to another checkout.
Terminal tests use an isolated configuration and a real PTY, including actual
pairs.nvim integration when available. Set `NVIM_BIN` to choose Neovim.

## Title case

`require("editing_tools").titlecase(first, last, opts)` applies English title
case to an inclusive one-based line range. It uses the same edit/undo path as
`apply("titlecase", range, opts)`; the latter also supports character/block ranges.
`opts.small_words` replaces the default list of lower-case words.
`opts.preserve = { api = "API", ios = "iOS" }` preserves explicit spellings.
Default casing normalizes ASCII words and starts each line with a capital; it
cannot infer proper names, acronyms or language-specific Unicode casing rules.
The plugin publishes titlecase Plug endpoints without choosing physical keys.
