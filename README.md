# editing-tools.nvim

Text objects and editing operators built on one range API. Requires Neovim 0.12+.
No plugin dependencies. Pair insertion and surround belong to a pairing plugin.

```lua
require("editing_tools").setup()
vim.keymap.set({ "o", "x" }, "i", "<Plug>(EditingTools-inside)")
vim.keymap.set({ "o", "x" }, "a", "<Plug>(EditingTools-around)")
vim.keymap.set({ "n", "x" }, "gx", "<Plug>(EditingTools-exchange)")
vim.keymap.set("n", "gxx", "<Plug>(EditingTools-exchange-line)")
```

Setup defines namespaced commands and `<Plug>` endpoints without assigning user
keys. The keys below are a suggested layout. Bind them in your configuration;
transient alignment controls remain local to the active preview.

Startup registers these entry points and validates options. Text-object scanning,
Tree-sitter queries, operators, alignment, exchange and Visual insertion load on
their first corresponding action. Ordinary Insert mode does not load them.
Reconfiguration cancels sessions that have already loaded without initializing
unused features.

Text-object endpoints are `inside`, `around`, `inside_next`, `around_next`,
`inside_prev`, and `around_prev`; movement endpoints are `goto_start` and
`goto_end`; Visual insertion uses `insert_visual` and `append_visual`.
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

## Text objects

Text objects work with native operators and Visual mode. Use `i` / `a` for inside /
around, `in` / `an` for the next object, and `il` / `al` for the previous object.
Counts choose enclosing objects from smallest to largest, or the nth next/previous
object. Native `w`, `W`, `s`, and `p` objects pass through to Vim.

| Key | Object |
| --- | --- |
| `b`, `(`, `)`, `[`, `]`, `{`, `}` | Balanced brackets; inner whitespace trimmed |
| `q`, `"`, `'`, backtick | Ordinary quoted strings |
| `a` | Comma-separated argument; nested brackets and strings protected |
| `u`, `U` | Function call, with / without member chain in the name |
| `d`, `e`, `_`, space | Digits, subword, underscore segment, whitespace |
| `t`, `<`, `>` | Matching tags, angle brackets |
| `i`, `g` | Indentation block, entire buffer (linewise) |
| `f`, `c`, `o` | Tree-sitter function, class, block/conditional/loop |

Whitespace-only bracket interiors remain selectable. Empty objects can be changed
with `c`, including dot-repeat; other operators cancel on a zero-width object.

`g[` / `g]` followed by an object key move to its start / exclusive end.
Tree-sitter parsers are optional. Queries ship for Lua, Python, JavaScript,
TypeScript, TSX, Bash, Fish, C/C++/CUDA, CMake, Rust, Swift, Java,
SystemVerilog, GDScript, MATLAB, Nix, HTML, CSS, JSON, YAML, TOML,
Markdown, LaTeX, BibTeX and Vue. Other languages can supply
`queries/<lang>/textobjects.scm`. Injected languages use their own queries.
Query data inherited from nvim-treesitter-textobjects is pinned and attributed in
`THIRD_PARTY.md`; its Lua plugin is not required. Parsers remain externally managed.

Lexical and indentation objects scan at most 500 lines on each side and 1 MiB by
default. Tree-sitter uses the installed parser and searches captures within the
configured line window. Bracket/quote,
argument, call, and tag objects use lexical rules, not language grammars. They do
not parse comments, raw strings, language-specific literals, HTML void elements,
or quoted `>` characters in attributes. Use Tree-sitter providers when those
distinctions matter.

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
  search = { lines = 500, max_bytes = 1024 * 1024 },
  align = { delimiter = "=", occurrence = "all", justify = "left",
    padding = 1, trim = true, outside = true },
  sort = { numeric = false, ignore_case = false, reverse = false },
  objects = {
    z = function(ctx)
      -- Return zero-based byte ranges with an exclusive finish.
      return { { start = { ctx.pos[1], 0 }, finish = { ctx.pos[1], 1 } } }
    end,
    t = false, -- Disable an object.
  },
  treesitter = { f = { inside = "function.inner", around = "function.outer" } },
})
```

All `mappings` entries default to `false`. Explicit `mappings = { exchange =
"gx" }` remains an opt-in convenience; prefer binding the public endpoints in
user configuration. Setup replaces only mappings still owned by this plugin.
Recommended keys such as `gx` and `ga` replace native actions only if you bind them.

The module name is `editing_tools`. Public APIs:

- `find(id, "inside"|"around", opts)` returns a range or `nil`.
  Options: zero-based `pos`, `buf`, `count`, `direction` (`current`, `next`, `prev`),
  and optional `reference` range for expanding a selection.
- `select(id, kind, opts)` selects a found object in the current window.
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

Custom providers receive `{ id, kind, buf, pos, first, last }`; `first`/`last` are
the zero-based search window with an exclusive `last`. They return a list of
valid ranges or `{}`. Providers must not modify the buffer. To use Tree-sitter
queries from another plugin, keep that plugin on runtimepath; editing-tools does
not require nvim-treesitter-textobjects itself.

`:EditingTools {action}` operates on the current line; `:'<,'>EditingTools sort`
and `:%EditingTools align =>` accept a line range. `:checkhealth editing_tools`
checks runtime and the current language's query. See `:help editing-tools`.

## Validation

```sh
sh tests/run.sh
python3 tests/tui.py
stylua --check lua plugin tests
```

Query tests use locally installed Lua, Python, JavaScript, TypeScript and TSX parsers from
`~/.local/share/nvim/site`; set `EDITING_TOOLS_PARSER_DIR` to another runtime
directory containing `parser/`. Terminal tests use an isolated configuration and
a real PTY, check intermediate screen contents, and do not load your config.
The integration suite uses actual sibling `pairs.nvim` and `motion-tools.nvim`
checkouts when present. Set `NVIM_BIN` to choose a different Neovim executable.

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
