# editing-tools.nvim

Text objects and editing operators built on one range API. Requires Neovim 0.12+.
No plugin dependencies. Pair insertion and surround belong to a pairing plugin.

```lua
require("editing_tools").setup()
```

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
TypeScript, and TSX; other languages can supply `queries/<lang>/textobjects.scm`.

Lexical and indentation objects scan at most 500 lines on each side and 1 MiB by
default. Tree-sitter uses the installed parser and searches captures within the
configured line window. Bracket/quote,
argument, call, and tag objects use lexical rules, not language grammars. They do
not parse comments, raw strings, language-specific literals, HTML void elements,
or quoted `>` characters in attributes. Use Tree-sitter providers when those
distinctions matter.

## Configuration and API

```lua
require("editing_tools").setup({
  mappings = { exchange = "gx", replace = "cr", evaluate = false },
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

Each mapping can be disabled with `false` or `""`. Setup replaces only mappings
still owned by this plugin. It installs mappings on request; simply adding the
plugin to runtimepath does not install them. The default `gx` and `ga` replace
Vim's URI opener and character information commands; choose other prefixes to
retain those commands.

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
