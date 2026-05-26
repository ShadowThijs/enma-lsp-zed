#!/usr/bin/env bash
set -euo pipefail

HELIX_BIN="${HELIX_BIN:-/usr/bin/helix}"
HELIX_RUNTIME="${HELIX_RUNTIME:-/usr/lib/helix/runtime}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/helix"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GRAMMAR_NAME="enma"

echo "Installing Enma for Helix..."

# ── LSP binary (needs sudo for /usr/local/bin) ──────────────────────────
# But try without sudo first (for user-owned installs)
if [ -f "$SCRIPT_DIR/enma-lsp" ]; then
  if [ -w "/usr/local/bin" ]; then
    cp "$SCRIPT_DIR/enma-lsp" /usr/local/bin/enma-lsp
    chmod +x /usr/local/bin/enma-lsp
  else
    sudo cp "$SCRIPT_DIR/enma-lsp" /usr/local/bin/enma-lsp
    sudo chmod +x /usr/local/bin/enma-lsp
  fi
  echo "  enma-lsp → /usr/local/bin/enma-lsp"
fi

# ── Tree-sitter grammar (needs sudo) ────────────────────────────────────
sudo mkdir -p "$HELIX_RUNTIME/grammars"
sudo cp "$SCRIPT_DIR/runtime/grammars/enma."* "$HELIX_RUNTIME/grammars/"
echo "  grammar → $HELIX_RUNTIME/grammars/"

# ── Queries (needs sudo) ────────────────────────────────────────────────
sudo mkdir -p "$HELIX_RUNTIME/queries/enma"
sudo cp "$SCRIPT_DIR/runtime/queries/enma/"*.scm "$HELIX_RUNTIME/queries/enma/"
echo "  queries → $HELIX_RUNTIME/queries/enma/"

# ── Language config (USER dir — no sudo) ────────────────────────────────
mkdir -p "$CONFIG"
CONFIG_FILE="$CONFIG/languages.toml"

if [ -f "$CONFIG_FILE" ] && grep -q 'name = "enma"' "$CONFIG_FILE" 2>/dev/null; then
  echo "  config already present in $CONFIG_FILE (skipped)"
else
  cat "$SCRIPT_DIR/languages.toml" >> "$CONFIG_FILE"
  echo "  config appended → $CONFIG_FILE"
fi

echo ""
echo "Done! Restart Helix and open any .em file."
echo "Verify: helix --health enma"
