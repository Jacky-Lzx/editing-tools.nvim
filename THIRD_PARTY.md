# Third-party query data

The textobjects.scm files in queries/ for bash, fish, c, cpp, cuda, cmake, rust, swift, java, systemverilog, gdscript, matlab, nix, html, css, json, yaml, toml, markdown, latex, bibtex, vue are vendored from
[nvim-treesitter/nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
at commit `5c7b0263797dfd1bd6202f2b219f3b53a80b2187` (Apache-2.0).
The upstream license is included at `licenses/nvim-treesitter-textobjects-Apache-2.0.txt`.
The files retain their query text, with provenance comments added, except Fish:
its function body uses quantified child captures so native ranges include the
complete final statement. The modification is marked in the query file. C++ and CUDA
retain their inheritance directives first. These files use native Neovim query
predicates/directives; no upstream Lua runtime is included or required.

Existing Lua, Python, JavaScript, TypeScript and TSX queries remain the project's
own definitions. Query changes should be validated against the parser versions
used by consumers. Grammar upgrades can require query updates.
