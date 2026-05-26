cargo clean 2>/dev/null
cargo clean --manifest-path enma-lsp/Cargo.toml 2>/dev/null
echo "✓ cargo cache cleared"

cargo build --release 2>&1 | grep -E "^error" || echo "✓ Extension built"
cargo build --manifest-path enma-lsp/Cargo.toml --release 2>&1 | grep -E "^error" || echo "✓ LSP built"

REV=$(git ls-remote https://github.com/shadowthijs/enma-lsp-zed HEAD | cut -f1)
sed -i "s/^rev = \".*\"/rev = \"$REV\"/" extension.toml

git add extension.toml
git commit -m "fix: Update rev tag in extension.toml"
git push
