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

Command palette (`Ctrl+Shift+P`):

```
enma.bundle
```

Or bind a key in `keymap.json`:
```json
{
  "context": "Editor && language == enma",
  "bindings": {
    "ctrl-shift-b": ["lsp::ExecuteCommand", { "command": "enma.bundle" }]
  }
}
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
