# enma-lsp

Language server and editor integrations for the [Enma](https://enma-1.gitbook.io/enma) scripting language.

## Disclaimer

> **This LSP as an extension is still very early in development, please do not hesitate to open an [issue](https://github.com/ShadowThijs/enma-lsp-zed/issues/new) if something is not working or contact me on discord @shadowthijs**

## Features

- Syntax highlighting and language grammar (tree-sitter)
- Diagnostics (syntax errors, type checking, duplicate detection)
- Completions (keywords, types, methods, fields)
- Hover (type info, documentation)
- Go-to-definition and references
- Document symbols and outline
- **Code formatter** with 80-char wrapping
- **Import bundler** — inlines all imports into a single self-contained file

## Supported Editors

| Editor | Syntax | LSP | Formatting | Bundler |
|--------|--------|-----|------------|---------|
| Zed    | ✓     | ✓  | ✓ | — |
| VSCode | ✓     | ✓  | ✓ | ✓ (palette) |
| Neovim | ✓     | ✓  | ✓ | ✓ (`:EnmaBundle`) |
| Helix  | ✓     | ✓  | ✓ | — |

## Installation

### Zed

You will have to install this as a dev extension if you want to use this inside Zed:

```sh
git clone https://github.com/shadowthijs/enma-lsp-zed.git
```

Then go into Zed and select this folder as the source folder for the dev extension.

### VSCode

Grab the latest `.vsix` from [releases](https://github.com/shadowthijs/enma-lsp-zed/releases) and install:

```sh
code --install-extension enma-lsp-*.vsix
```

Or build from source:

```sh
make vscode
code --install-extension editors/vscode/enma-lsp-*.vsix
```

### Neovim

```sh
make nvim
cd editors/nvim && ./install.sh   # or install.ps1 on Windows
```

Requires nvim ≥ 0.9. The install script copies the LSP binary, tree-sitter parser, and queries. LazyVim is auto-detected.
(Please let me know if you want implementation for other plugin managers)

### Helix

```sh
make helix
cd editors/helix && ./install.sh   # or install.ps1 on Windows
```

## Building

```sh
make          # build all editor packages
make lsp      # LSP server binary only
make parser   # tree-sitter shared library
make vscode   # VSCode extension (requires npm)
make nvim     # Neovim plugin artifacts
make helix    # Helix config artifacts
```

Build requirements: Rust toolchain, C compiler, Node.js + npm (for VSCode).

## Bundler

Inlines all `import "path"` statements into a single self-contained `.em` file.
Import loops are detected (warning emitted, no crash). Comment stripping is optional.

> **Zed users**: Zed does not yet support LSP `workspace/executeCommand` natively.
> The Zed team is working on adding this — for now use VSCode or Neovim to bundle,
> or wait until the feature lands in Zed.

See [`enma-lsp/COMMANDS.md`](enma-lsp/COMMANDS.md) for editor-specific usage.

## Project Structure

```
enma-lsp-zed/
  enma-lsp/          Rust LSP server + formatter + bundler
  tree-sitter-enma/  Tree-sitter grammar (C + JS)
  editors/
    vscode/          VSCode extension (TypeScript)
    nvim/            Neovim plugin (Lua)
    helix/           Helix config (TOML + queries)
  src/               Zed extension (Rust WASM)
  languages/         Zed language config + queries
  test/              Test fixtures
  examples/          Example .em files
```

## License

MIT
