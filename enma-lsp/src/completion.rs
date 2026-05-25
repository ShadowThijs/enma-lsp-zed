use crate::semantic::SemanticModel;
use crate::type_db::{FreeFunction, MethodInfo, TypeDatabase};
use tower_lsp::lsp_types::*;

pub struct CompletionContext<'a> {
    pub db: &'static TypeDatabase,
    pub model: &'a SemanticModel,
}

impl<'a> CompletionContext<'a> {
    pub fn new(db: &'static TypeDatabase, model: &'a SemanticModel) -> Self {
        Self { db, model }
    }

    pub fn complete(
        &self,
        source: &str,
        position: Position,
    ) -> Vec<CompletionItem> {
        let offset = position_to_offset(source, position);
        let before = &source[..offset.min(source.len())];

        // After a dot: method/field completions
        if let Some(identifier) = identifier_before_dot(before) {
            return self.dot_completions(&identifier);
        }

        // Global scope: keywords + type names + free functions
        let mut items = Vec::new();
        items.extend(self.keyword_completions());
        items.extend(self.type_completions());
        items.extend(self.function_completions());
        items
    }

    fn dot_completions(&self, ident: &str) -> Vec<CompletionItem> {
        let mut items = Vec::new();

        // Look up the identifier in the semantic model to find its type
        let var_type = self.model.symbols.iter()
            .find(|s| s.name == ident && s.var_type.is_some())
            .and_then(|s| s.var_type.as_deref());

        // Also check if it's a type itself (struct/class)
        let is_type = self.model.symbols.iter()
            .any(|s| s.name == ident && matches!(s.kind, crate::semantic::SymbolKind::Struct | crate::semantic::SymbolKind::Class));

        // If it's a struct/class, show its fields and methods
        if is_type {
            if let Some(type_sym) = self.model.symbols.iter()
                .find(|s| s.name == ident) {
                for field in &type_sym.fields {
                    items.push(CompletionItem {
                        label: field.name.clone(),
                        kind: Some(CompletionItemKind::FIELD),
                        detail: field.field_type.clone(),
                        ..Default::default()
                    });
                }
                for method in &type_sym.methods {
                    items.push(CompletionItem {
                        label: method.name.clone(),
                        kind: Some(CompletionItemKind::METHOD),
                        detail: method.return_type.clone(),
                        ..Default::default()
                    });
                }
            }
        }

        // If we know the type, show its methods from the type database
        if let Some(typ) = var_type {
            if let Some(methods) = self.db.get_methods(typ) {
                for m in methods {
                    items.push(method_to_item(m));
                }
            }
            if let Some(fields) = self.db.get_fields(typ) {
                for f in fields {
                    items.push(CompletionItem {
                        label: f.clone(),
                        kind: Some(CompletionItemKind::FIELD),
                        detail: Some(format!("{} field", typ)),
                        ..Default::default()
                    });
                }
            }
        }

        // Also try the identifier itself as a type name
        if let Some(methods) = self.db.get_methods(ident) {
            for m in methods {
                items.push(method_to_item(m));
            }
        }

        items
    }

    fn keyword_completions(&self) -> Vec<CompletionItem> {
        self.db.keywords.iter().map(|k| CompletionItem {
            label: k.clone(),
            kind: Some(CompletionItemKind::KEYWORD),
            ..Default::default()
        }).collect()
    }

    fn type_completions(&self) -> Vec<CompletionItem> {
        let mut items: Vec<_> = self.db.all_type_names.iter().map(|t| CompletionItem {
            label: t.clone(),
            kind: Some(CompletionItemKind::CLASS),
            detail: Some("type".into()),
            ..Default::default()
        }).collect();

        // Add custom types from the semantic model
        for sym in &self.model.symbols {
            if matches!(sym.kind, crate::semantic::SymbolKind::Struct | crate::semantic::SymbolKind::Class) {
                if !items.iter().any(|i| i.label == sym.name) {
                    items.push(CompletionItem {
                        label: sym.name.clone(),
                        kind: Some(CompletionItemKind::STRUCT),
                        detail: Some(format!("custom {}", match sym.kind { crate::semantic::SymbolKind::Struct => "struct", _ => "class" })),
                        ..Default::default()
                    });
                }
            }
        }
        items
    }

    fn function_completions(&self) -> Vec<CompletionItem> {
        let mut items: Vec<_> = self.db.functions.values().map(|f| function_to_item(f)).collect();

        // Add custom functions from the semantic model
        for sym in &self.model.symbols {
            if sym.kind == crate::semantic::SymbolKind::Function {
                if !items.iter().any(|i| i.label == sym.name) {
                    items.push(CompletionItem {
                        label: sym.name.clone(),
                        kind: Some(CompletionItemKind::FUNCTION),
                        detail: sym.type_name.clone(),
                        ..Default::default()
                    });
                }
            }
        }
        items
    }
}

fn method_to_item(m: &MethodInfo) -> CompletionItem {
    let detail = TypeDatabase::method_detail(m);
    let insert = if m.params.is_empty() {
        format!("{}()", m.name)
    } else {
        format!("{}({})", m.name, m.params.iter().map(|p| p.name.as_str()).collect::<Vec<_>>().join(", "))
    };
    CompletionItem {
        label: m.name.clone(),
        kind: Some(CompletionItemKind::METHOD),
        detail: Some(detail),
        documentation: if m.doc.is_empty() { None } else { Some(Documentation::String(m.doc.clone())) },
        insert_text: Some(insert),
        insert_text_format: Some(InsertTextFormat::PLAIN_TEXT),
        ..Default::default()
    }
}

fn function_to_item(f: &FreeFunction) -> CompletionItem {
    let detail = TypeDatabase::function_detail(f);
    CompletionItem {
        label: f.name.clone(),
        kind: Some(CompletionItemKind::FUNCTION),
        detail: Some(detail.clone()),
        documentation: if f.doc.is_empty() { None } else { Some(Documentation::String(f.doc.clone())) },
        insert_text: Some(format!("{}({})", f.name, f.params.iter().map(|p| p.name.as_str()).collect::<Vec<_>>().join(", "))),
        insert_text_format: Some(InsertTextFormat::PLAIN_TEXT),
        ..Default::default()
    }
}

fn position_to_offset(source: &str, pos: Position) -> usize {
    let mut offset = 0;
    for (i, line) in source.lines().enumerate() {
        if i as u32 == pos.line {
            offset += pos.character as usize;
            break;
        }
        offset += line.len() + 1;
    }
    offset.min(source.len())
}

fn identifier_before_dot(before: &str) -> Option<String> {
    let trimmed = before.trim_end();
    if !trimmed.ends_with('.') {
        return None;
    }
    let without_dot = &trimmed[..trimmed.len() - 1];
    // Extract the last identifier before the dot
    let ident = without_dot.rsplit(|c: char| !c.is_alphanumeric() && c != '_').next()?;
    if ident.is_empty() { None } else { Some(ident.to_string()) }
}
