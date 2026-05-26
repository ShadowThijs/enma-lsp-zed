fn main() {
    let src_dir = std::path::PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").unwrap())
        .join("src");

    let mut build = cc::Build::new();
    build
        .include(&src_dir)
        .flag_if_supported("-std=c11")
        .file(src_dir.join("parser.c"));

    // scanner.c is optional - only add if it exists
    let scanner = src_dir.join("scanner.c");
    if scanner.exists() {
        build.file(&scanner);
        println!("cargo:rerun-if-changed=src/scanner.c");
    }

    build.compile("tree-sitter-enma");

    println!("cargo:rerun-if-changed=src/parser.c");
}
