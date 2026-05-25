fn main() {
    let parser_c = "../tree-sitter-enma/src/parser.c";
    println!("cargo:rerun-if-changed={}", parser_c);
    println!("cargo:rerun-if-changed=build.rs");

    cc::Build::new()
        .file(parser_c)
        .include("../tree-sitter-enma/src")
        .compile("tree-sitter-enma");
}
