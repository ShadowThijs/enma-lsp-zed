use crate::type_db::{FreeFunction, MethodInfo, TypeDatabase};
use tower_lsp::lsp_types::*;

pub struct CompletionContext {
    pub db: &'static TypeDatabase,
}

impl CompletionContext {
    pub fn new(db: &'static TypeDatabase) -> Self {
        Self { db }
    }

    /// Produce completions at a given position in the parse tree.
    pub fn complete(
        &self,
        source: &str,
        position: Position,
    ) -> Vec<CompletionItem> {
        let offset = position_to_offset(source, position);
        let before = &source[..offset.min(source.len())];

        // Determine context from the text before cursor
        if let Some(after_dot) = after_dot(before) {
            return self.method_completions(after_dot);
        }

        if before.ends_with("::") || before.contains("::") && !before.ends_with("::") {
            return self.scope_completions();
        }

        // Global scope: keywords + type names + free functions
        let mut items = Vec::new();
        items.extend(self.keyword_completions());
        items.extend(self.type_completions());
        items.extend(self.function_completions());
        items
    }

    /// Completions after `.` — methods on the left type.
    fn method_completions(&self, type_name: &str) -> Vec<CompletionItem> {
        // Check known types
        if let Some(methods) = self.db.get_methods(type_name) {
            return methods.iter().map(|m| method_to_item(m)).collect();
        }

        // Check math types
        if let Some(mt) = self.db.math_types.get(type_name) {
            let mut items: Vec<_> = mt.fields.iter().map(|f| CompletionItem {
                label: f.clone(),
                kind: Some(CompletionItemKind::FIELD),
                detail: Some(format!("{} (field)", type_name)),
                ..Default::default()
            }).collect();

            items.extend(mt.methods.iter().map(|m| method_to_item(m)));
            return items;
        }


        Vec::new()
    }

    /// `::` scope completions — enum values, namespace members.
    fn scope_completions(&self) -> Vec<CompletionItem> {
        // For now, return nothing — scope resolution needs semantic analysis
        Vec::new()
    }

    /// Keyword completions.
    fn keyword_completions(&self) -> Vec<CompletionItem> {
        self.db
            .keywords
            .iter()
            .map(|k| CompletionItem {
                label: k.clone(),
                kind: Some(CompletionItemKind::KEYWORD),
                ..Default::default()
            })
            .collect()
    }

    /// Type name completions.
    fn type_completions(&self) -> Vec<CompletionItem> {
        self.db
            .all_type_names
            .iter()
            .map(|t| CompletionItem {
                label: t.clone(),
                kind: Some(CompletionItemKind::CLASS),
                detail: Some("type".into()),
                ..Default::default()
            })
            .collect()
    }

    /// Free function completions.
    fn function_completions(&self) -> Vec<CompletionItem> {
        self.db
            .functions
            .values()
            .map(|f| function_to_item(f))
            .collect()
    }
}

fn method_to_item(m: &MethodInfo) -> CompletionItem {
    let detail = TypeDatabase::method_detail(m);
    CompletionItem {
        label: m.name.clone(),
        kind: Some(CompletionItemKind::METHOD),
        detail: Some(detail),
        documentation: if m.doc.is_empty() {
            None
        } else {
            Some(Documentation::String(m.doc.clone()))
        },
        ..Default::default()
    }
}

fn function_to_item(f: &FreeFunction) -> CompletionItem {
    let detail = TypeDatabase::function_detail(f);
    CompletionItem {
        label: f.name.clone(),
        kind: Some(CompletionItemKind::FUNCTION),
        detail: Some(detail.clone()),
        documentation: if f.doc.is_empty() {
            None
        } else {
            Some(Documentation::String(f.doc.clone()))
        },
        // Add snippet-style insert for functions with params
        insert_text: Some(format!("{}({})", f.name, f.params.iter().map(|p| p.name.as_str()).collect::<Vec<_>>().join(", "))),
        insert_text_format: Some(InsertTextFormat::PLAIN_TEXT),
        ..Default::default()
    }
}

/// Convert a line/column position to byte offset.
fn position_to_offset(source: &str, pos: Position) -> usize {
    let mut offset = 0;
    for (i, line) in source.lines().enumerate() {
        if i as u32 == pos.line {
            offset += pos.character as usize;
            break;
        }
        offset += line.len() + 1; // +1 for newline
    }
    offset.min(source.len())
}

/// If the text before cursor ends with `.identifier`, return the identifier.
/// This detects `expr.method|` patterns for method completion.
fn after_dot(before: &str) -> Option<&str> {
    // Find the last segment after a dot
    // Case: `str.|` → we need to know the type of `str`
    // For now, simple heuristic: look for common patterns

    // TODO: proper type inference from the parse tree
    // For now, only handle explicit type info from nearby tree-sitter nodes
    None
}
