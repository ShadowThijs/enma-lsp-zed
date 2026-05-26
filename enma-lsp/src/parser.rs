use anyhow::Result;
use tree_sitter::{Parser, Tree};

pub struct EnmaParser {
    parser: Parser,
}

impl EnmaParser {
    pub fn new() -> Result<Self> {
        let mut parser = Parser::new();
        let lang_fn = unsafe { tree_sitter_enma() };
        let language = unsafe { tree_sitter::Language::from_raw(lang_fn as *const _) };
        parser.set_language(&language)?;
        Ok(Self { parser })
    }

    pub fn parse(&mut self, source: &[u8]) -> Option<Tree> {
        self.parser.parse(source, None)
    }
}

extern "C" {
    pub fn tree_sitter_enma() -> *const std::ffi::c_void;
}
