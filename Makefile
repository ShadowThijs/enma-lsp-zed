# Enma Language Distribution — single build entry point
#   make          builds everything
#   make lsp      LSP server binary only
#   make parser   tree-sitter shared library + queries
#   make vscode   VSCode extension
#   make nvim     Neovim plugin artifacts
#   make helix    Helix config artifacts
#   make clean    remove all build artifacts

# ── Platform ────────────────────────────────────────────────────────────────
# Normalize OS detection (works on Linux, macOS, Windows/MSYS2/MinGW, WSL)
ifeq ($(OS),Windows_NT)
  PLATFORM := windows
else
  UNAME_S := $(shell uname -s 2>/dev/null || echo Windows)
  ifeq ($(UNAME_S),Linux)
    PLATFORM := linux
  else ifeq ($(UNAME_S),Darwin)
    PLATFORM := macos
  else
    PLATFORM := windows  # fallback (MINGW*, CYGWIN*, MSYS*)
  endif
endif

# Shared library extension
ifeq ($(PLATFORM),windows)
  SHLIB_EXT := dll
else ifeq ($(PLATFORM),macos)
  SHLIB_EXT := dylib
else
  SHLIB_EXT := so
endif

# Binary extension
ifeq ($(PLATFORM),windows)
  BIN_EXT := .exe
else
  BIN_EXT :=
endif

# C compiler and flags for building the tree-sitter shared library
ifeq ($(PLATFORM),windows)
  # Try MinGW gcc first (common in MSYS2/Git Bash), fall back to MSVC cl
  CC := $(shell which gcc 2>/dev/null || which clang 2>/dev/null || echo cl)
  ifeq ($(CC),cl)
    SHLIB_CFLAGS := /LD /Fe
    SHLIB_LFLAGS :=
  else
    SHLIB_CFLAGS := -shared -fPIC
    SHLIB_LFLAGS :=
  endif
else
  CC := $(shell which cc 2>/dev/null || which gcc 2>/dev/null || which clang 2>/dev/null)
  SHLIB_CFLAGS := -shared -fPIC
  ifeq ($(PLATFORM),macos)
    SHLIB_LFLAGS := -install_name @rpath/enma.$(SHLIB_EXT)
  else
    SHLIB_LFLAGS :=
  endif
endif

.SILENT:
.PHONY: all lsp parser vscode nvim helix clean

# ── Directories ─────────────────────────────────────────────────────────────
DIST     := editors/dist
LSP_DIR  := enma-lsp
PARSER_C := tree-sitter-enma/src/parser.c
PARSER_I := tree-sitter-enma/src
QUERIES  := grammars/enma/tree-sitter-enma/queries

all: vscode nvim helix
	@echo "✓ All editor packages built (platform: $(PLATFORM))"

# ── LSP Server ──────────────────────────────────────────────────────────────
lsp:
	@echo "Building enma-lsp..."
	cd $(LSP_DIR) && cargo build --release 2>&1 | tail -3
	mkdir -p $(DIST)/lsp
	cp $(LSP_DIR)/target/release/enma-lsp$(BIN_EXT) $(DIST)/lsp/
	@echo "  → $(DIST)/lsp/enma-lsp$(BIN_EXT)"

# ── Tree-sitter Parser ──────────────────────────────────────────────────────
parser:
	@echo "Building tree-sitter-enma shared library ($(SHLIB_EXT))..."
	mkdir -p $(DIST)/parser $(DIST)/queries
	$(CC) $(SHLIB_CFLAGS) -o $(DIST)/parser/enma.$(SHLIB_EXT) \
		$(PARSER_C) -I$(PARSER_I) -std=c11 -O2 $(SHLIB_LFLAGS)
	cp $(QUERIES)/highlights.scm $(DIST)/queries/
	cp $(QUERIES)/brackets.scm $(DIST)/queries/
	cp $(QUERIES)/indents.scm $(DIST)/queries/
	cp $(QUERIES)/outline.scm $(DIST)/queries/
	@echo "  → $(DIST)/parser/enma.$(SHLIB_EXT)"
	@echo "  → $(DIST)/queries/*.scm"

# ── VSCode Extension ────────────────────────────────────────────────────────
VSC_DIR := editors/vscode

vscode: lsp
	@echo "Packaging VSCode extension..."
	mkdir -p $(VSC_DIR) $(VSC_DIR)/out
	cp $(DIST)/lsp/enma-lsp$(BIN_EXT) $(VSC_DIR)/
	@if [ ! -d "$(VSC_DIR)/node_modules" ]; then \
		cd $(VSC_DIR) && npm install 2>&1 | tail -3; \
	fi
	cd $(VSC_DIR) && node build.mjs 2>&1 | grep "Done\|error" || true
	cd $(VSC_DIR) && npx vsce package --allow-missing-repository 2>&1 | tail -1
	@echo "  → $(VSC_DIR)/enma-lsp-*.vsix"

# ── Neovim Plugin ───────────────────────────────────────────────────────────
NVIM_DIR := editors/nvim

nvim: lsp parser
	@echo "Preparing Neovim plugin..."
	mkdir -p $(NVIM_DIR)/parser $(NVIM_DIR)/queries/enma
	cp $(DIST)/lsp/enma-lsp$(BIN_EXT) $(NVIM_DIR)/enma-lsp$(BIN_EXT)
	cp $(DIST)/parser/enma.$(SHLIB_EXT) $(NVIM_DIR)/parser/enma.$(SHLIB_EXT)
	cp $(DIST)/queries/highlights.scm $(NVIM_DIR)/queries/enma/
	cp $(DIST)/queries/brackets.scm $(NVIM_DIR)/queries/enma/
	cp $(DIST)/queries/indents.scm $(NVIM_DIR)/queries/enma/
	cp $(DIST)/queries/outline.scm $(NVIM_DIR)/queries/enma/
	@echo "  → $(NVIM_DIR)/enma-lsp$(BIN_EXT)"
	@echo "  → $(NVIM_DIR)/parser/enma.$(SHLIB_EXT)"
	@echo "  → $(NVIM_DIR)/queries/enma/*.scm"
	@echo "  Run 'cd editors/nvim && ./install.sh' (Linux/macOS) or 'install.ps1' (Windows)"

# ── Helix Config ────────────────────────────────────────────────────────────
HELIX_DIR := editors/helix

helix: lsp parser
	@echo "Preparing Helix config..."
	mkdir -p $(HELIX_DIR)/runtime/grammars $(HELIX_DIR)/runtime/queries/enma
	cp $(DIST)/lsp/enma-lsp$(BIN_EXT) $(HELIX_DIR)/enma-lsp$(BIN_EXT)
	cp $(DIST)/parser/enma.$(SHLIB_EXT) $(HELIX_DIR)/runtime/grammars/enma.$(SHLIB_EXT)
	cp $(DIST)/queries/highlights.scm $(HELIX_DIR)/runtime/queries/enma/
	cp $(DIST)/queries/brackets.scm $(HELIX_DIR)/runtime/queries/enma/
	cp $(DIST)/queries/indents.scm $(HELIX_DIR)/runtime/queries/enma/indents.scm
	cp $(DIST)/queries/outline.scm $(HELIX_DIR)/runtime/queries/enma/
	@echo "  → $(HELIX_DIR)/enma-lsp$(BIN_EXT)"
	@echo "  → $(HELIX_DIR)/runtime/grammars/enma.$(SHLIB_EXT)"
	@echo "  → $(HELIX_DIR)/runtime/queries/enma/*.scm"
	@echo "  Run 'cd editors/helix && ./install.sh' (Linux/macOS) or 'install.ps1' (Windows)"

# ── Clean ───────────────────────────────────────────────────────────────────
clean:
	@echo "Cleaning..."
	cd $(LSP_DIR) && cargo clean 2>/dev/null; true
	rm -rf $(DIST)
	rm -f $(VSC_DIR)/enma-lsp$(BIN_EXT)
	rm -f $(VSC_DIR)/enma-lsp-*.vsix
	rm -rf $(VSC_DIR)/out
	rm -rf $(VSC_DIR)/node_modules
	rm -f $(NVIM_DIR)/enma-lsp$(BIN_EXT)
	rm -f $(NVIM_DIR)/parser/enma.*
	rm -rf $(NVIM_DIR)/queries
	rm -f $(HELIX_DIR)/enma-lsp$(BIN_EXT)
	rm -f $(HELIX_DIR)/runtime/grammars/enma.*
	rm -rf $(HELIX_DIR)/runtime/queries
	@echo "  ✓ clean"
