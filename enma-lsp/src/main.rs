mod parser;
mod type_db;
mod completion;
mod semantic;

use parser::EnmaParser;
use type_db::TypeDatabase;
use completion::CompletionContext;
use semantic::SemanticModel;
use std::collections::HashMap;
use std::sync::OnceLock;
use tokio::sync::Mutex;
use tower_lsp::jsonrpc::Result as LspResult;
use tower_lsp::lsp_types::*;
use tower_lsp::{Client, LanguageServer, LspService, Server};

static TYPE_DB: OnceLock<TypeDatabase> = OnceLock::new();

fn get_db() -> &'static TypeDatabase {
    TYPE_DB.get_or_init(TypeDatabase::load)
}

struct Backend {
    client: Client,
    parser: Mutex<EnmaParser>,
    documents: Mutex<HashMap<Url, String>>,
}

#[tower_lsp::async_trait]
impl LanguageServer for Backend {
    async fn initialize(&self, _: InitializeParams) -> LspResult<InitializeResult> {
        Ok(InitializeResult {
            capabilities: ServerCapabilities {
                text_document_sync: Some(TextDocumentSyncCapability::Kind(
                    TextDocumentSyncKind::FULL,
                )),
                completion_provider: Some(CompletionOptions {
                    trigger_characters: Some(vec![".".into(), ":".into(), "(".into(), ",".into()]),
                    ..Default::default()
                }),
                hover_provider: Some(HoverProviderCapability::Simple(true)),
                definition_provider: Some(OneOf::Left(true)),
                references_provider: Some(OneOf::Left(true)),
                document_symbol_provider: Some(OneOf::Left(true)),
                signature_help_provider: Some(SignatureHelpOptions {
                    trigger_characters: Some(vec!["(".into(), ",".into()]),
                    ..Default::default()
                }),
                ..Default::default()
            },
            server_info: Some(ServerInfo {
                name: "enma-lsp".into(),
                version: Some("0.1.0".into()),
            }),
        })
    }

    async fn shutdown(&self) -> LspResult<()> {
        Ok(())
    }

    async fn did_open(&self, params: DidOpenTextDocumentParams) {
        let uri = params.text_document.uri.clone();
        let text = params.text_document.text;
        self.documents.lock().await.insert(uri.clone(), text.clone());
        self.publish_diagnostics(&uri, &text).await;
    }

    async fn did_change(&self, params: DidChangeTextDocumentParams) {
        let uri = params.text_document.uri.clone();
        if let Some(change) = params.content_changes.into_iter().next() {
            self.documents.lock().await.insert(uri.clone(), change.text.clone());
            self.publish_diagnostics(&uri, &change.text).await;
        }
    }

    async fn did_close(&self, params: DidCloseTextDocumentParams) {
        self.documents.lock().await.remove(&params.text_document.uri);
    }

    async fn completion(&self, params: CompletionParams) -> LspResult<Option<CompletionResponse>> {
        let uri = params.text_document_position.text_document.uri.clone();
        let pos = params.text_document_position.position;

        let docs = self.documents.lock().await;
        if let Some(source) = docs.get(&uri) {
            if let Some(model) = self.build_model(source).await {
                let ctx = CompletionContext::new(get_db(), &model);
                let items = ctx.complete(source, pos);
                if !items.is_empty() {
                    return Ok(Some(CompletionResponse::Array(items)));
                }
            }
        }
        Ok(None)
    }

    async fn hover(&self, params: HoverParams) -> LspResult<Option<Hover>> {
        let uri = params.text_document_position_params.text_document.uri.clone();
        let pos = params.text_document_position_params.position;

        let docs = self.documents.lock().await;
        if let Some(source) = docs.get(&uri) {
            if let Some(model) = self.build_model(source).await {
                let mut parser = self.parser.lock().await;
                let (token_text, token_range, is_ident) = if let Some(tree) = parser.parse(source.as_bytes()) {
                    let node = find_named_leaf(tree.root_node(), pos);
                    // Accept identifiers AND any leaf node (keywords, operators, etc.)
                    if node.kind() == "identifier" || node.child_count() == 0 {
                        let text = source[node.start_byte()..node.end_byte()].to_string();
                        (Some(text), Some(node_range(&node)), node.kind() == "identifier")
                    } else {
                        (None, None, false)
                    }
                } else {
                    (None, None, false)
                };

                if let Some(ref name) = token_text {
                    // Identifier-specific: try local symbol lookup
                    if is_ident {
                        // Step 1: declaration-site
                        if let Some(sym) = model.symbols.iter()
                            .filter(|s| s.name == *name && range_contains(&s.range, pos))
                            .min_by_key(|s| {
                                let lines = (s.range.end.line - s.range.start.line) as u64;
                                let chars = s.range.end.character.abs_diff(s.range.start.character) as u64;
                                lines * 1000 + chars
                            })
                        {
                            let markdown = format_local_symbol_hover(&sym);
                            if !markdown.is_empty() {
                                return Ok(Some(Hover {
                                    contents: HoverContents::Markup(MarkupContent {
                                        kind: MarkupKind::Markdown,
                                        value: markdown,
                                    }),
                                    range: token_range,
                                }));
                            }
                        }

                        // Step 2: reference-site — find the definition for this name.
                        // Prefer function/struct/class/enum definitions over locals.
                        let ref_sym = model.symbols.iter()
                            .filter(|s| s.name == *name && !range_contains(&s.range, pos))
                            .max_by_key(|s| {
                                // Prioritize definition-like symbols (higher score = first pick)
                                match s.kind {
                                    semantic::SymbolKind::Function => 5,
                                    semantic::SymbolKind::Struct => 4,
                                    semantic::SymbolKind::Class => 4,
                                    semantic::SymbolKind::Enum => 4,
                                    semantic::SymbolKind::Interface => 3,
                                    semantic::SymbolKind::Namespace => 2,
                                    semantic::SymbolKind::Variable => 1,
                                    semantic::SymbolKind::Parameter => 0,
                                    semantic::SymbolKind::TypeAlias => 2,
                                }
                            });
                        if let Some(sym) = ref_sym {
                            let def_md = format_local_symbol_hover(sym);
                            if !def_md.is_empty() {
                                let markdown = format!("*reference to {}*\n\n{}",
                                    match sym.kind {
                                        semantic::SymbolKind::Function => "function",
                                        semantic::SymbolKind::Variable => "variable",
                                        semantic::SymbolKind::Parameter => "parameter",
                                        semantic::SymbolKind::Struct => "struct",
                                        semantic::SymbolKind::Class => "class",
                                        semantic::SymbolKind::Enum => "enum",
                                        semantic::SymbolKind::Interface => "interface",
                                        semantic::SymbolKind::Namespace => "namespace",
                                        semantic::SymbolKind::TypeAlias => "type alias",
                                    },
                                    def_md,
                                );
                                return Ok(Some(Hover {
                                    contents: HoverContents::Markup(MarkupContent {
                                        kind: MarkupKind::Markdown,
                                        value: markdown,
                                    }),
                                    range: token_range,
                                }));
                            }
                        }
                    }

                    // Step 3: fallback to type database (functions, types, keywords)
                    let db = get_db();
                    let markdown = format_type_db_hover(db, name);
                    if !markdown.is_empty() {
                        return Ok(Some(Hover {
                            contents: HoverContents::Markup(MarkupContent {
                                kind: MarkupKind::Markdown,
                                value: markdown,
                            }),
                            range: token_range,
                        }));
                    }
                }
            }
        }
        Ok(None)
    }

    async fn goto_definition(
        &self,
        params: GotoDefinitionParams,
    ) -> LspResult<Option<GotoDefinitionResponse>> {
        let uri = params.text_document_position_params.text_document.uri.clone();
        let pos = params.text_document_position_params.position;

        let docs = self.documents.lock().await;
        if let Some(source) = docs.get(&uri) {
            // Parse and walk to find the identifier at cursor
            let mut parser = self.parser.lock().await;
            if let Some(tree) = parser.parse(source.as_bytes()) {
                let node = find_named_leaf(tree.root_node(), pos);
                if node.kind() == "identifier" {
                    let name = &source[node.start_byte()..node.end_byte()];
                    let model = SemanticModel::build(tree.root_node(), source, get_db());
                    // Find a symbol definition with this name (not at this position)
                    for sym in &model.symbols {
                        if sym.name == name && !range_contains(&sym.range, pos) {
                            return Ok(Some(GotoDefinitionResponse::Scalar(Location {
                                uri: uri.clone(),
                                range: sym.range,
                            })));
                        }
                    }
                }
            }
        }
        Ok(None)
    }

    async fn references(
        &self,
        _params: ReferenceParams,
    ) -> LspResult<Option<Vec<Location>>> {
        Ok(None)
    }

    async fn document_symbol(
        &self,
        params: DocumentSymbolParams,
    ) -> LspResult<Option<DocumentSymbolResponse>> {
        let uri = params.text_document.uri.clone();
        let docs = self.documents.lock().await;
        if let Some(source) = docs.get(&uri) {
            if let Some(model) = self.build_model(source).await {
                let symbols: Vec<DocumentSymbol> = model.symbols.iter().map(|sym| {
                    let kind = match sym.kind {
                        semantic::SymbolKind::Function => SymbolKind::FUNCTION,
                        semantic::SymbolKind::Struct => SymbolKind::STRUCT,
                        semantic::SymbolKind::Class => SymbolKind::CLASS,
                        semantic::SymbolKind::Enum => SymbolKind::ENUM,
                        semantic::SymbolKind::Interface => SymbolKind::INTERFACE,
                        semantic::SymbolKind::Namespace => SymbolKind::NAMESPACE,
                        semantic::SymbolKind::Variable => SymbolKind::VARIABLE,
                        semantic::SymbolKind::Parameter => SymbolKind::VARIABLE,
                        semantic::SymbolKind::TypeAlias => SymbolKind::TYPE_PARAMETER,
                    };
                    DocumentSymbol {
                        name: sym.name.clone(),
                        detail: sym.type_name.clone(),
                        kind,
                        tags: None,
                        deprecated: None,
                        range: sym.range,
                        selection_range: sym.range,
                        children: None,
                    }
                }).collect();
                return Ok(Some(DocumentSymbolResponse::Nested(symbols)));
            }
        }
        Ok(None)
    }

    async fn signature_help(
        &self,
        _params: SignatureHelpParams,
    ) -> LspResult<Option<SignatureHelp>> {
        Ok(None)
    }
}

impl Backend {
    async fn build_model(&self, source: &str) -> Option<SemanticModel> {
        let mut parser = self.parser.lock().await;
        let tree = parser.parse(source.as_bytes())?;
        Some(SemanticModel::build(tree.root_node(), source, get_db()))
    }

    async fn publish_diagnostics(&self, uri: &Url, text: &str) {
        let mut parser = self.parser.lock().await;
        let tree = parser.parse(text.as_bytes());

        let diagnostics = if let Some(tree) = &tree {
            let mut diags = self.collect_syntax_errors(tree.root_node());
            let model = SemanticModel::build(tree.root_node(), text, get_db());
            diags.extend(model.diagnostics());
            diags
        } else {
            vec![Diagnostic {
                range: Range::default(),
                severity: Some(DiagnosticSeverity::ERROR),
                message: "Failed to parse file".into(),
                ..Default::default()
            }]
        };

        self.client
            .publish_diagnostics(uri.clone(), diagnostics, None)
            .await;
    }

    fn collect_syntax_errors(
        &self,
        node: tree_sitter::Node,
    ) -> Vec<Diagnostic> {
        let mut results = Vec::new();

        if node.is_error() || node.is_missing() {
            // Only report leaf errors — skip large ERROR nodes that contain
            // children (those children will be reported individually).
            if node.child_count() == 0 {
                results.push(Diagnostic {
                    range: node_range(&node),
                    severity: Some(DiagnosticSeverity::ERROR),
                    code: Some(NumberOrString::String("syntax-error".into())),
                    source: Some("enma-lsp".into()),
                    message: if node.is_missing() {
                        format!("Missing: {}", node.kind())
                    } else {
                        "Syntax error".into()
                    },
                    ..Default::default()
                });
            }
        }

        let mut cursor = node.walk();
        for child in node.children(&mut cursor) {
            results.extend(self.collect_syntax_errors(child));
        }

        results
    }
}

fn format_local_symbol_hover(sym: &semantic::Symbol) -> String {
    let kind_str = match sym.kind {
        semantic::SymbolKind::Function => "function",
        semantic::SymbolKind::Variable => "variable",
        semantic::SymbolKind::Parameter => "parameter",
        semantic::SymbolKind::Struct => "struct",
        semantic::SymbolKind::Class => "class",
        semantic::SymbolKind::Enum => "enum",
        semantic::SymbolKind::Interface => "interface",
        semantic::SymbolKind::Namespace => "namespace",
        semantic::SymbolKind::TypeAlias => "type alias",
    };

    match sym.kind {
        semantic::SymbolKind::Function => {
            let mut md = format!("```enma\nfn {}", sym.name);
            // Parameters
            if !sym.params.is_empty() {
                let params: Vec<String> = sym.params.iter()
                    .map(|(n, t)| {
                        if let Some(ty) = t { format!("{}: {}", n, ty) } else { n.clone() }
                    })
                    .collect();
                md.push_str(&format!("({})", params.join(", ")));
            } else {
                md.push_str("()");
            }
            if let Some(ref ret) = sym.return_type {
                md.push_str(&format!(" -> {}", ret));
            }
            md.push_str("\n```\n");

            md.push_str(&format!("**{}** `{}`", kind_str, sym.name));
            if let Some(ref ret) = sym.return_type {
                md.push_str(&format!(" → {}", ret));
            }
            md.push('\n');

            if !sym.params.is_empty() {
                md.push_str("\n**Parameters:**\n");
                for (pn, pt) in &sym.params {
                    if let Some(ty) = pt {
                        md.push_str(&format!("- `{}: {}`\n", pn, ty));
                    } else {
                        md.push_str(&format!("- `{}`\n", pn));
                    }
                }
            }
            md
        }

        semantic::SymbolKind::Struct | semantic::SymbolKind::Class => {
            let mut md = format!("```enma\n{} {}", kind_str, sym.name);
            if !sym.fields.is_empty() || !sym.methods.is_empty() {
                md.push_str(" {\n");
                for f in &sym.fields {
                    if let Some(ref ft) = f.field_type {
                        md.push_str(&format!("    {}: {};\n", f.name, ft));
                    } else {
                        md.push_str(&format!("    {};\n", f.name));
                    }
                }
                if !sym.fields.is_empty() && !sym.methods.is_empty() {
                    md.push('\n');
                }
                for m in &sym.methods {
                    md.push_str("    fn ");
                    md.push_str(&m.name);
                    if !m.params.is_empty() {
                        let pstrs: Vec<String> = m.params.iter()
                            .map(|(n, t)| {
                                if let Some(ty) = t { format!("{}: {}", n, ty) } else { n.clone() }
                            })
                            .collect();
                        md.push_str(&format!("({})", pstrs.join(", ")));
                    } else {
                        md.push_str("()");
                    }
                    if let Some(ref rt) = m.return_type {
                        md.push_str(&format!(" -> {}", rt));
                    }
                    md.push_str(";\n");
                }
                md.push_str("}\n");
            }
            md.push_str("```\n");

            md.push_str(&format!("**{}** `{}`", kind_str, sym.name));
            let fc = sym.fields.len();
            let mc = sym.methods.len();
            md.push_str(&format!(" — {} field{}, {} method{}",
                fc, if fc == 1 { "" } else { "s" },
                mc, if mc == 1 { "" } else { "s" }));
            md.push('\n');

            if !sym.fields.is_empty() {
                md.push_str("\n**Fields:**\n");
                for f in &sym.fields {
                    if let Some(ref ft) = f.field_type {
                        md.push_str(&format!("- `{}: {}`\n", f.name, ft));
                    } else {
                        md.push_str(&format!("- `{}`\n", f.name));
                    }
                }
            }
            if !sym.methods.is_empty() {
                md.push_str("\n**Methods:**\n");
                for m in &sym.methods {
                    md.push_str(&format!("- `{}`", m.name));
                    if !m.params.is_empty() {
                        let pstrs: Vec<String> = m.params.iter()
                            .map(|(n, t)| {
                                if let Some(ty) = t { format!("{}: {}", n, ty) } else { n.clone() }
                            })
                            .collect();
                        md.push_str(&format!("({})", pstrs.join(", ")));
                    } else {
                        md.push_str("()");
                    }
                    if let Some(ref rt) = m.return_type {
                        md.push_str(&format!(" → {}", rt));
                    }
                    md.push('\n');
                }
            }
            md
        }

        semantic::SymbolKind::Enum => {
            let mut md = format!("```enma\nenum {} {{\n", sym.name);
            for v in &sym.enum_variants {
                md.push_str(&format!("    {},\n", v));
            }
            md.push_str("}\n```\n");

            md.push_str(&format!("**enum** `{}`", sym.name));
            let vc = sym.enum_variants.len();
            if vc > 0 {
                md.push_str(&format!(" — {} variant{}", vc, if vc == 1 { "" } else { "s" }));
            }
            md.push('\n');

            if !sym.enum_variants.is_empty() {
                md.push_str("\n**Variants:**\n");
                for v in &sym.enum_variants {
                    md.push_str(&format!("- `{}`\n", v));
                }
            }
            md
        }

        semantic::SymbolKind::Variable | semantic::SymbolKind::Parameter => {
            let vt = sym.var_type.as_deref().unwrap_or("unknown");
            let mut md = format!("```enma\n{} {}: {}\n```\n", kind_str, sym.name, vt);
            md.push_str(&format!("**{}** `{}`\n\n", kind_str, sym.name));
            md.push_str(&format!("**Type:** `{}`", vt));
            md
        }

        _ => {
            format!("```enma\n{} {}\n```\n**{}** `{}`", kind_str, sym.name, kind_str, sym.name)
        }
    }
}

fn format_type_db_hover(db: &TypeDatabase, name: &str) -> String {
    // Check free functions first (most specific match)
    if let Some(f) = db.functions.get(name) {
        let mut md = String::from("```enma\nfn ");
        md.push_str(&f.name);
        md.push('(');
        let params: Vec<String> = f.params.iter()
            .map(|p| format!("{}: {}", p.name, p.r#type))
            .collect();
        md.push_str(&params.join(", "));
        if f.variadic {
            if !params.is_empty() { md.push_str(", "); }
            md.push_str("...");
        }
        md.push(')');
        md.push_str(&format!(" -> {}", f.r#return));
        md.push_str("\n```\n");

        md.push_str(&format!("**built-in function** `{}`", f.name));
        if f.r#return != "void" {
            md.push_str(&format!(" → `{}`", f.r#return));
        }
        if !f.module.is_empty() {
            md.push_str(&format!("\n\n*Module: `{}`*", f.module));
        }

        if !f.doc.is_empty() {
            md.push_str("\n\n---\n");
            md.push_str(&f.doc);
        } else if !f.params.is_empty() {
            md.push_str("\n\n**Parameters:**\n");
            for p in &f.params {
                md.push_str(&format!("- `{}: {}`\n", p.name, p.r#type));
            }
        }
        return md;
    }

    // Check types
    if db.is_type(name) {
        let mut md = format!("```enma\ntype {}\n```\n", name);
        md.push_str(&format!("**built-in type** `{}`", name));

        if let Some(doc) = db.get_type_doc(name) {
            md.push_str(&format!("\n\n{}", doc));
        }

        if let Some(methods) = db.get_methods(name) {
            if !methods.is_empty() {
                md.push_str(&format!("\n\n**{} methods:**\n", methods.len()));
                for m in methods.iter().take(20) {
                    md.push_str(&format!("- `{}`", m.name));
                    if !m.params.is_empty() {
                        let pstrs: Vec<String> = m.params.iter()
                            .map(|p| format!("{}: {}", p.name, p.r#type))
                            .collect();
                        md.push_str(&format!("({})", pstrs.join(", ")));
                    } else {
                        md.push_str("()");
                    }
                    if m.r#return != "void" {
                        md.push_str(&format!(" → `{}`", m.r#return));
                    }
                    if !m.doc.is_empty() {
                        md.push_str(&format!(" — {}", m.doc));
                    }
                    md.push('\n');
                }
                if methods.len() > 20 {
                    md.push_str(&format!("- ... and {} more\n", methods.len() - 20));
                }
            }
        }

        if let Some(fields) = db.get_fields(name) {
            if !fields.is_empty() {
                md.push_str("\n**Fields:** ");
                let fstrs: Vec<String> = fields.iter().map(|f| format!("`{}`", f)).collect();
                md.push_str(&fstrs.join(", "));
                md.push('\n');
            }
        }

        if let Some(module_funcs) = db.module_functions.get(name) {
            if !module_funcs.is_empty() {
                md.push_str(&format!("\n**{} associated functions:**\n", module_funcs.len()));
                for ff in module_funcs.iter().take(15) {
                    md.push_str(&format!("- `{}(", ff.name));
                    let pstrs: Vec<String> = ff.params.iter()
                        .map(|p| format!("{}: {}", p.name, p.r#type))
                        .collect();
                    md.push_str(&pstrs.join(", "));
                    md.push_str(&format!(") → {}`\n", ff.r#return));
                }
                if module_funcs.len() > 15 {
                    md.push_str(&format!("- ... and {} more\n", module_funcs.len() - 15));
                }
            }
        }
        return md;
    }

    // Search all types' methods for a matching method name
    let mut method_md = String::new();
    for (type_name, methods) in &db.types {
        for m in methods {
            if m.name == name {
                method_md.push_str(&format!("```enma\n{}.{}(", type_name, m.name));
                let pstrs: Vec<String> = m.params.iter().map(|p| format!("{}: {}", p.name, p.r#type)).collect();
                method_md.push_str(&pstrs.join(", "));
                method_md.push_str(&format!(") -> {}\n```\n", m.r#return));
                method_md.push_str(&format!("**method** `{}::{}`", type_name, m.name));
                if m.r#return != "void" { method_md.push_str(&format!(" → `{}`", m.r#return)); }
                if !m.doc.is_empty() { method_md.push_str(&format!("\n\n{}", m.doc)); }
                if !m.params.is_empty() {
                    method_md.push_str("\n\n**Parameters:**\n");
                    for p in &m.params { method_md.push_str(&format!("- `{}: {}`\n", p.name, p.r#type)); }
                }
            }
        }
    }
    for (type_name, mt) in &db.math_types {
        for m in &mt.methods {
            if m.name == name {
                method_md.push_str(&format!("```enma\n{}.{}(", type_name, m.name));
                let pstrs: Vec<String> = m.params.iter().map(|p| format!("{}: {}", p.name, p.r#type)).collect();
                method_md.push_str(&pstrs.join(", "));
                method_md.push_str(&format!(") -> {}\n```\n", m.r#return));
                method_md.push_str(&format!("**method** `{}::{}`", type_name, m.name));
                if m.r#return != "void" { method_md.push_str(&format!(" → `{}`", m.r#return)); }
                if !m.doc.is_empty() { method_md.push_str(&format!("\n\n{}", m.doc)); }
                if !m.params.is_empty() {
                    method_md.push_str("\n\n**Parameters:**\n");
                    for p in &m.params { method_md.push_str(&format!("- `{}: {}`\n", p.name, p.r#type)); }
                }
            }
        }
    }
    if !method_md.is_empty() {
        return method_md;
    }

    // Check if it's a primitive
    if db.is_primitive(name) {
        let doc = db.get_keyword_doc(name).unwrap_or("");
        if !doc.is_empty() {
            return format!("```enma\n{}\n```\n**primitive type** `{}`\n\n{}", name, name, doc);
        }
        return format!("```enma\n{}\n```\n**primitive type** `{}`", name, name);
    }

    // Check if it's a language keyword
    if let Some(doc) = db.get_keyword_doc(name) {
        let label = if db.keywords.contains(&name.to_string()) { "keyword" } else { "operator" };
        return format!("```enma\n{}\n```\n**language {}** `{}`\n\n{}", name, label, name, doc);
    }

    // Also check with brackets stripped for things like delete[]
    // (tree-sitter may parse "delete[]" as one token or "delete" + "[]")
    if let Some(stripped) = name.strip_suffix("[]") {
        if let Some(doc) = db.get_keyword_doc(stripped) {
            return format!("```enma\n{}\n```\n**language operator** `{}`\n\n{}", name, name, doc);
        }
    }

    String::new()
}

fn range_contains(range: &Range, pos: Position) -> bool {
    pos >= range.start && pos <= range.end
}

fn find_named_leaf(node: tree_sitter::Node, pos: Position) -> tree_sitter::Node {
    let target = Position { line: pos.line, character: pos.character };
    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        let cr = node_range(&child);
        if range_contains(&cr, target) {
            if child.child_count() == 0 || child.kind() == "identifier" {
                return child;
            }
            return find_named_leaf(child, pos);
        }
    }
    node
}

fn node_range(node: &tree_sitter::Node) -> Range {
    let start = node.start_position();
    let end = node.end_position();

    Range {
        start: Position {
            line: start.row as u32,
            character: start.column as u32,
        },
        end: Position {
            line: end.row as u32,
            character: end.column as u32,
        },
    }
}

#[tokio::main]
async fn main() {
    env_logger::init();

    let parser = EnmaParser::new().expect("Failed to initialize Enma parser");

    let (service, socket) = LspService::new(|client| Backend {
        client,
        parser: Mutex::new(parser),
        documents: Mutex::new(HashMap::new()),
    });

    Server::new(tokio::io::stdin(), tokio::io::stdout(), socket)
        .serve(service)
        .await;
}
