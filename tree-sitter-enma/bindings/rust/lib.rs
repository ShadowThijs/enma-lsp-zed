use tree_sitter_language::LanguageFn;

extern "C" {
    fn tree_sitter_enma() -> LanguageFn;
}

/// Returns the tree-sitter [LanguageFn] for Enma.
pub fn language() -> LanguageFn {
    unsafe { tree_sitter_enma() }
}

/// Returns the tree-sitter [Language] for Enma.
#[cfg(feature = "language")]
pub fn language_enma() -> tree_sitter_language::Language {
    unsafe { tree_sitter_enma().into() }
}
