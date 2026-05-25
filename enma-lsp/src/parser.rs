use anyhow::Result;
use tree_sitter::{Parser, Tree};

/// Wrapper around tree-sitter for Enma language parsing.
pub struct EnmaParser {
    parser: Parser,
}

impl EnmaParser {
    pub fn new() -> Result<Self> {
        let mut parser = Parser::new();
        let language = unsafe { tree_sitter_enma() };
        parser.set_language(&language)?;
        Ok(Self { parser })
    }

    pub fn parse(&mut self, source: &[u8]) -> Option<Tree> {
        self.parser.parse(source, None)
    }
}

extern "C" {
    fn tree_sitter_enma() -> tree_sitter::Language;
}
