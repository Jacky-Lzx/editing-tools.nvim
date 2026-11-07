# editing-tools.nvim

Editing operators, alignment and insertion across selected lines.

## Features

- Replace, exchange, duplicate, sort and evaluate selections.
- Preview alignment before applying a single edit.
- Bind namespaced commands and <Plug> endpoints to your own keys.

## Requirements

Neovim **0.12+**. `motion-tools.nvim` is required for ranges and lexical scanning. Syntax-aware objects need their parsers.

## Installation

With lazy.nvim:

```lua
{
  "Jacky-Lzx/editing-tools.nvim",
  main = "editing_tools",
  dependencies = { "Jacky-Lzx/motion-tools.nvim" },
  opts = {},
}
```

Or put this repository and its required dependencies on `runtimepath`, then call:

```lua
require("editing_tools").setup({})
```

## Usage

```vim
:EditingTools cancel
```

Bind the exchange operator explicitly:

```lua
vim.keymap.set({ "n", "x" }, "gx", "<Plug>(EditingTools-exchange)")
vim.keymap.set("n", "gxx", "<Plug>(EditingTools-exchange-line)")
```

With the example mappings, `gxiw` selects a word for exchange. Move to another
word and repeat `gxiw` to exchange the two selections. Use the cancel command
above to release a pending selection.

## Documentation

- [Complete reference](doc/editing-tools.txt) — `:help editing-tools`.
- [Workflow and integration guide](doc/guide.md).
- Diagnose availability with `:checkhealth editing_tools`.

## Development

Run from the repository root:

```sh
python3 tests/run.py unit --filter docs
python3 tests/run.py default
```

See [the test workflow](tests/README.md) for dependencies, optional suites and
retained failure evidence. Local development overrides belong in your package
manager configuration; public installation uses the repository above.

[License](LICENSE).
