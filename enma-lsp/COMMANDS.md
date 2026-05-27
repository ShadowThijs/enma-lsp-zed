# Enma Bundle — Editor Commands

Bundle all imported `.em` scripts into a single self-contained file.
Existing files are never overwritten — delete the output file first
or choose a different path.

## VSCode

Command palette (`Ctrl+Shift+P`):

```
Enma: Bundle Imports
```

Prompts for output path (default: `output/bundled.em`) and comment stripping.

## Zed

Zed does not yet support LSP `workspace/executeCommand` natively.
The Zed team is working on adding this — for now use VSCode or Neovim
to bundle, or wait until the feature lands.
```

## Neovim

```
:EnmaBundle              " prompts for output path (default: output/bundled.em)
:EnmaBundle!             " strip comments + prompt for output path
:EnmaBundle output.em    " bundle to specific path
```

Lua API:
```lua
require('enma').bundle({ strip_comments = true, output = 'output/bundled.em' })
```
