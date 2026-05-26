#!/usr/bin/env bash
set -euo pipefail

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
BIN_DIR="$HOME/.local/bin"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Enma for Neovim..."

# ── LSP binary → ~/.local/bin ──────────────────────────────────────────
mkdir -p "$BIN_DIR"
if [ -f "$SCRIPT_DIR/enma-lsp" ]; then
  cp "$SCRIPT_DIR/enma-lsp" "$BIN_DIR/enma-lsp"
  chmod +x "$BIN_DIR/enma-lsp"
  echo "  enma-lsp → $BIN_DIR/enma-lsp"
fi
if [ -f "$SCRIPT_DIR/enma-lsp.exe" ]; then
  cp "$SCRIPT_DIR/enma-lsp.exe" "$BIN_DIR/enma-lsp.exe"
  echo "  enma-lsp.exe → $BIN_DIR/enma-lsp.exe"
fi

# ── Tree-sitter parser ──────────────────────────────────────────────────
mkdir -p "$DATA/site/parser"
cp "$SCRIPT_DIR/parser/enma."* "$DATA/site/parser/" 2>/dev/null
echo "  parser → $DATA/site/parser/"

# ── Queries ─────────────────────────────────────────────────────────────
rm -rf "$DATA/site/queries/enma"
mkdir -p "$DATA/site/queries/enma"
cp "$SCRIPT_DIR/queries/enma/"*.scm "$DATA/site/queries/enma/"
echo "  queries → $DATA/site/queries/enma/"

# ── Lua plugin files (works standalone) ─────────────────────────────────
mkdir -p "$CONFIG/lua/enma"
cp "$SCRIPT_DIR/lua/enma/init.lua" "$CONFIG/lua/enma/"
mkdir -p "$CONFIG/plugin"
cp "$SCRIPT_DIR/plugin/enma.lua" "$CONFIG/plugin/"
echo "  plugin → $CONFIG/plugin/enma.lua"

# ── LazyVim plugin spec (if LazyVim/lazy.nvim is detected) ─────────────
LAZY_PLUGINS="$CONFIG/lua/plugins"
if [ -d "$LAZY_PLUGINS" ] || [ -d "$CONFIG/lazy-lock.json" ]; then
  mkdir -p "$LAZY_PLUGINS"
  cp "$SCRIPT_DIR/lua/plugins/enma.lazyvim.lua" "$LAZY_PLUGINS/enma.lua"
  echo "  lazyvim spec → $LAZY_PLUGINS/enma.lua"
fi

# ── Ensure ~/.local/bin is in PATH ─────────────────────────────────────
if ! echo "$PATH" | tr ':' '\n' | grep -qxF "$BIN_DIR"; then
  echo ""
  echo "NOTE: $BIN_DIR is not in your current PATH."
  echo "Add this to ~/.bashrc or ~/.zshrc:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'
fi

echo ""
echo "Done. Open any .em file in Neovim — syntax highlighting and LSP are active."
