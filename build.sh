cargo clean
cargo clean --manifest-path enma-lsp/Cargo.toml

cargo build --release
cargo build --manifest-path enma-lsp/Cargo.toml --release

REV=$(git ls-remote https://github.com/shadowthijs/enma-lsp-zed HEAD | cut -f1)
sed -i "s/^rev = \".*\"/rev = \"$REV\"/" extension.toml

git add extension.toml
git commit -m "fix: Update rev tag in extension.toml"
git push
