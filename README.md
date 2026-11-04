# editing-tools.nvim

Text objects and editing operators built on one range API. Requires Neovim 0.11+.
No plugin dependencies. Pair insertion and surround belong to a pairing plugin.

```lua
require("editing_tools").setup()
```

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

`g[` / `g]` followed by an object key move to its start / exclusive end.
Tree-sitter parsers are optional. Queries ship for Lua, Python, JavaScript,
TypeScript, and TSX; other languages can supply `queries/<lang>/textobjects.scm`.

Objects scan at most 500 lines on each side and 1 MiB by default. Bracket/quote,
argument, call, and tag objects use lexical rules, not language grammars. They do
not parse comments, raw strings, language-specific literals, HTML void elements,
or quoted `>` characters in attributes. Use Tree-sitter providers when those
distinctions matter.

Run `sh tests/run.sh` and `stylua --check lua tests` to validate the plugin.
