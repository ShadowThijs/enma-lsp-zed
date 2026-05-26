use tree_sitter_language::LanguageFn;

extern "C" {
    fn tree_sitter_enma() -> LanguageFn;
}

pub fn language() -> LanguageFn {
    unsafe { tree_sitter_enma() }
}
