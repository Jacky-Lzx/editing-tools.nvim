# editing-tools.nvim

Editing operators, alignment and multi-line insertion. Requires Neovim 0.12+
and motion-tools.nvim on runtimepath for range handling and lexical scanning.
Object recognition, text-object selection and navigation belong to motion-tools;
pair insertion and surround belong to a pairing plugin.

```lua
require("editing_tools").setup()
vim.keymap.set({ "n", "x" }, "gx", "<Plug>(EditingTools-exchange)")
vim.keymap.set("n", "gxx", "<Plug>(EditingTools-exchange-line)")
```

Setup defines namespaced commands and `<Plug>` endpoints without assigning user
keys. The keys below are a suggested layout. Bind them in your configuration;
transient alignment controls remain local to the active preview.

Startup registers these entry points and validates options. Operators, range
utilities, alignment, exchange and Visual insertion load on
their first corresponding action. Ordinary Insert mode does not load them.
Reconfiguration cancels sessions that have already loaded without initializing
unused features.

Visual insertion endpoints are `insert_visual` and `append_visual`.
Operator endpoints are `replace`, `exchange`, `multiply`, `sort`, `evaluate`,
and `align`, with `-line` variants for Normal-mode line operations. All use the
`<Plug>(EditingTools-<action>)` spelling.

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

## Configuration and API

```lua
require("editing_tools").setup({
  align = { delimiter = "=", occurrence = "all", justify = "left",
    padding = 1, trim = true, outside = true },
  sort = { numeric = false, ignore_case = false, reverse = false },

})
```

All `mappings` entries default to `false`. Explicit `mappings = { exchange =
"gx" }` remains an opt-in convenience; prefer binding the public endpoints in
user configuration. Setup replaces only mappings still owned by this plugin.
Recommended keys such as `gx` and `ga` replace native actions only if you bind them.

The module name is `editing_tools`. Public APIs:

- `apply(action, range, opts)` applies a synchronous edit. Options include `buf`,
  sort settings, `register`, `times` (additional copies), and `evaluator`.
- `operator(action, opts)` returns `g@` for an expression mapping.
- `align(range, opts)` opens the interactive preview.
- `align_lines(lines, opts)` is a pure transformation.
- `cancel_exchange()` clears the pending exchange.

A range is `{ start = { row, byte }, finish = { row, byte }, mode = "char"|"line" }`.
Positions are zero-based and `finish` is exclusive. Line ranges include both
endpoint rows; their columns should be `0` and the final line's byte length.
Block ranges come from `require("editing_tools.range").visual()` or
`from_positions()` and retain native virtual-column information. Ranges describe
a snapshot, not a persistent selection; only pending exchange uses extmarks.

`motion_tools.find_object()` supplies ranges when an API caller needs object
recognition. `editing_tools.range` extends the shared `motion_tools.range` with
`get`, `put`, and native `operator` range capture. Object configuration, queries
and the former `find`/`select` APIs have moved to motion-tools; configure
`motion_tools.setup({ textobjects = { search = ..., objects = ..., treesitter = ... } })`.
The `MotionToolsObjectCancelled` User event cancels a pending custom operator
without creating a reverse dependency from motion to editing.

`:EditingTools {action}` operates on the current line; `:'<,'>EditingTools sort`
and `:%EditingTools align =>` accept a line range. `:checkhealth editing_tools`
checks runtime and the motion-tools dependency. See `:help editing-tools`.

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

## Command ownership

Commands belong to the plugin; choose global entry keys and short aliases in
your configuration. Registration reports same-name conflicts without replacing
user commands. Reconfiguration refreshes only commands still owned by this
plugin, and cleanup preserves subsequent user replacements.

## Lifecycle and configuration

`setup(opts)` starts from fresh defaults and copies caller tables. Maps merge
recursively; lists replace defaults. Invalid options leave active edits and
mappings unchanged. `dispose()` cancels transient editing sessions and removes
only unchanged plugin-owned mappings, restoring displaced global mappings. It
can be called repeatedly or before setup. Later `setup()` starts from defaults;
stateless Lua actions and the plugin's command entry point remain available.

## Health and inspection

Health reports actionable failures and a compact result for applicable checks. Disabled,
optional and not-yet-activated features do not warn solely because they are inactive.
Inspection does not configure plugins, start services or install dependencies.
