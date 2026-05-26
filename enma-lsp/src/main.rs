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
            if let Some(model) = self.build_model_with_imports(source, &uri).await {
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
            let model = self.build_model_with_imports(source, &uri).await;
            let has_model = model.is_some();
            let sym_count = model.as_ref().map(|m| m.symbols.len()).unwrap_or(0);
            eprintln!("[hover] L{}:C{} | model={} syms={}", pos.line, pos.character, has_model, sym_count);

            if let Some(model) = model {
                let mut parser = self.parser.lock().await;
                let hover_info = if let Some(tree) = parser.parse(source.as_bytes()) {
                    let node = find_named_leaf(tree.root_node(), pos);
                    eprintln!("[hover] find_named_leaf: kind='{}' text='{}' children={}",
                        node.kind(),
                        &source[node.start_byte()..node.end_byte()],
                        node.child_count());

                    if node.kind() == "identifier" || node.child_count() == 0 {
                        let text = source[node.start_byte()..node.end_byte()].to_string();
                        let is_ident = node.kind() == "identifier";
                        let ctx = detect_context(node, source);
                        eprintln!("[hover] token='{}' is_ident={} ctx={:?} pos={}:{}",
                            text, is_ident, ctx, pos.line, pos.character);
                        let db = get_db();
                        let result = resolve_hover(&text, pos, is_ident, &ctx, &model, db);
                        match &result {
                            Some((_, path)) => eprintln!("[hover] RESOLVED via {}", path),
                            None => eprintln!("[hover] NO MATCH — func={} type={} prim={} kw={}",
                                db.functions.contains_key(&text),
                                db.is_type(&text),
                                db.is_primitive(&text),
                                db.get_keyword_doc(&text).is_some()),
                        }
                        result.map(|(md, _)| (md, node_range(&node)))
                    } else {
                        eprintln!("[hover] SKIP: node kind='{}' has children, not a leaf/ident", node.kind());
                        None
                    }
                } else {
                    eprintln!("[hover] SKIP: parser.parse returned None");
                    None
                };

                if let Some((markdown, range)) = hover_info {
                    return Ok(Some(Hover {
                        contents: HoverContents::Markup(MarkupContent {
                            kind: MarkupKind::Markdown,
                            value: markdown,
                        }),
                        range: Some(range),
                    }));
                }
            }
        } else {
            eprintln!("[hover] SKIP: source not found in documents");
        }
        eprintln!("[hover] RESULT: None");
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
            if let Some(model) = self.build_model_with_imports(source, &uri).await {
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
    /// Try to load a file from disk, given a directory and relative path.
    fn load_file_from_disk(base_dir: &std::path::Path, import_path: &str) -> Option<String> {
        let full = base_dir.join(import_path);
        // Try exact path first, then with .em extension
        if full.exists() {
            std::fs::read_to_string(&full).ok()
        } else {
            let with_em = base_dir.join(format!("{}.em", import_path));
            std::fs::read_to_string(&with_em).ok()
        }
    }

    /// Build a semantic model with import resolution. Loads imported files
    /// from disk or from already-opened documents. Resolves imports recursively
    /// with cycle detection (max 10 levels deep).
    async fn build_model_with_imports(
        &self,
        source: &str,
        uri: &Url,
    ) -> Option<SemanticModel> {
        let mut parser = self.parser.lock().await;
        let tree = parser.parse(source.as_bytes())?;
        let mut model = SemanticModel::build(tree.root_node(), source, get_db());
        // Release parser lock before doing I/O
        drop(parser);

        // Resolve the base directory from the URI
        let base_dir = if uri.scheme() == "file" {
            if let Some(path_str) = uri.to_file_path().ok() {
                path_str.parent().map(|p| p.to_path_buf())
            } else {
                None
            }
        } else {
            None
        };

        if let Some(base_dir) = base_dir {
            let imports = model.imports.clone();
            self.resolve_imports(&mut model, &base_dir, &imports).await;
        }

        Some(model)
    }

    async fn resolve_imports(
        &self,
        model: &mut SemanticModel,
        base_dir: &std::path::Path,
        initial_paths: &[String],
    ) {
        let mut to_process: Vec<String> = initial_paths.to_vec();
        let mut resolved: std::collections::HashSet<String> = std::collections::HashSet::new();
        let mut depth = 0;

        while !to_process.is_empty() && depth < 10 {
            let current: Vec<String> = to_process.drain(..).collect();
            for path in &current {
                if resolved.contains(path) { continue; }
                resolved.insert(path.clone());

                let full_path = base_dir.join(path);
                eprintln!("[import] trying: {:?}", full_path);
                let src = Self::load_file_from_disk(base_dir, path);
                if let Some(ref src) = src {
                    eprintln!("[import] loaded {} ({} bytes, {} syms)", path, src.len(),
                        src.lines().count());
                    let mut parser = self.parser.lock().await;
                    if let Some(import_tree) = parser.parse(src.as_bytes()) {
                        let import_model = SemanticModel::build(import_tree.root_node(), src, get_db());
                        eprintln!("[import] {} has {} symbols", path, import_model.symbols.len());
                        for sym in &import_model.symbols {
                            eprintln!("[import]   {:?} '{}' methods={}", sym.kind, sym.name, sym.methods.len());
                        }
                        let nested = import_model.imports.clone();
                        model.merge_import(import_model, path);
                        eprintln!("[import] merged, model now has {} symbols", model.symbols.len());
                        drop(parser);
                        to_process.extend(nested);
                    }
                } else {
                    eprintln!("[import] FAILED to load: {:?}", path);
                }
            }
            depth += 1;
        }
    }

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
            let mut model = SemanticModel::build(tree.root_node(), text, get_db());
            // Try to resolve imports for diagnostics
            let base_dir = if uri.scheme() == "file" {
                uri.to_file_path().ok().and_then(|p| p.parent().map(|p| p.to_path_buf()))
            } else { None };
            if let Some(ref base) = base_dir {
                let imports = model.imports.clone();
                let mut resolved: std::collections::HashSet<String> = std::collections::HashSet::new();
                for path in &imports {
                    if !resolved.contains(path) {
                        resolved.insert(path.clone());
                        if let Some(src) = Self::load_file_from_disk(base, path) {
                            if let Some(import_tree) = parser.parse(src.as_bytes()) {
                                let im = SemanticModel::build(import_tree.root_node(), &src, get_db());
                                model.merge_import(im, path);
                            }
                        }
                    }
                }
            }
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
                let (dtors, regular): (Vec<_>, Vec<_>) = sym.methods.iter()
                    .partition(|m| m.name.starts_with('~'));
                if !regular.is_empty() {
                    md.push_str(&format!("\n**{} method{}:**\n", regular.len(), if regular.len() == 1 { "" } else { "s" }));
                    for m in &regular {
                        md.push_str(&format!("- `{}`", m.name));
                        if !m.params.is_empty() {
                            let pstrs: Vec<String> = m.params.iter()
                                .map(|(n, t)| if let Some(ty) = t { format!("{}: {}", n, ty) } else { n.clone() })
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
                if !dtors.is_empty() {
                    md.push_str("\n**Cleanup:**\n");
                    for d in &dtors {
                        let clean_name = d.name.trim_start_matches('~');
                        md.push_str(&format!("- `~{}()` — destructor, runs when `delete` is called\n", clean_name));
                    }
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

/// Format hover for a method on a CUSTOM struct/class from the semantic model.
fn format_custom_struct_method(model: &SemanticModel, method_name: &str, type_name: &str) -> String {
    // Find the struct/class symbol in the model
    for sym in &model.symbols {
        if sym.name == type_name && (sym.kind == semantic::SymbolKind::Struct || sym.kind == semantic::SymbolKind::Class) {
            // Search its methods for the hovered name
            for m in &sym.methods {
                if m.name == method_name {
                    let kind_str = if sym.kind == semantic::SymbolKind::Struct { "struct" } else { "class" };
                    let mut md = format!("```enma\n{}.{}(", type_name, m.name);
                    let pstrs: Vec<String> = m.params.iter()
                        .map(|(n, t)| if let Some(ty) = t { format!("{}: {}", n, ty) } else { n.clone() })
                        .collect();
                    md.push_str(&pstrs.join(", "));
                    if let Some(ref rt) = m.return_type {
                        md.push_str(&format!(") -> {}", rt));
                    } else {
                        md.push(')');
                    }
                    md.push_str(&format!("\n```\n**method** `{}::{}`", type_name, m.name));
                    if let Some(ref rt) = m.return_type {
                        md.push_str(&format!(" → `{}`", rt));
                    }
                    md.push_str(&format!("\n\nDefined in {} `{}`", kind_str, type_name));
                    if !m.params.is_empty() {
                        md.push_str("\n\n**Parameters:**\n");
                        for (pn, pt) in &m.params {
                            if let Some(ty) = pt {
                                md.push_str(&format!("- `{}: {}`\n", pn, ty));
                            } else {
                                md.push_str(&format!("- `{}`\n", pn));
                            }
                        }
                    }
                    return md;
                }
            }
        }
    }
    String::new()
}

/// Format hover for a method on a SPECIFIC type (receiver type known).
fn format_method_hover_for_type(db: &TypeDatabase, method_name: &str, type_name: &str) -> String {
    let mut md = String::new();
    // Check types
    if let Some(methods) = db.get_methods(type_name) {
        for m in methods {
            if m.name == method_name {
                md.push_str(&format!("```enma\n{}.{}(", type_name, m.name));
                let pstrs: Vec<String> = m.params.iter().map(|p| format!("{}: {}", p.name, p.r#type)).collect();
                md.push_str(&pstrs.join(", "));
                md.push_str(&format!(") -> {}\n```\n", m.r#return));
                md.push_str(&format!("**method** `{}::{}`", type_name, m.name));
                if m.r#return != "void" { md.push_str(&format!(" → `{}`", m.r#return)); }
                if !m.doc.is_empty() { md.push_str(&format!("\n\n{}", m.doc)); }
                if !m.params.is_empty() {
                    md.push_str("\n\n**Parameters:**\n");
                    for p in &m.params { md.push_str(&format!("- `{}: {}`\n", p.name, p.r#type)); }
                }
            }
        }
    }
    // Also check math types
    if let Some(mt) = db.math_types.get(type_name) {
        for m in &mt.methods {
            if m.name == method_name {
                md.push_str(&format!("```enma\n{}.{}(", type_name, m.name));
                let pstrs: Vec<String> = m.params.iter().map(|p| format!("{}: {}", p.name, p.r#type)).collect();
                md.push_str(&pstrs.join(", "));
                md.push_str(&format!(") -> {}\n```\n", m.r#return));
                md.push_str(&format!("**method** `{}::{}`", type_name, m.name));
                if m.r#return != "void" { md.push_str(&format!(" → `{}`", m.r#return)); }
                if !m.doc.is_empty() { md.push_str(&format!("\n\n{}", m.doc)); }
                if !m.params.is_empty() {
                    md.push_str("\n\n**Parameters:**\n");
                    for p in &m.params { md.push_str(&format!("- `{}: {}`\n", p.name, p.r#type)); }
                }
            }
        }
    }
    md
}

/// Format hover for a method found by searching ALL types (receiver type unknown).
fn format_method_hover_all(db: &TypeDatabase, method_name: &str) -> String {
    let mut md = String::new();
    for (type_name, methods) in &db.types {
        for m in methods {
            if m.name == method_name {
                md.push_str(&format!("```enma\n{}.{}(", type_name, m.name));
                let pstrs: Vec<String> = m.params.iter().map(|p| format!("{}: {}", p.name, p.r#type)).collect();
                md.push_str(&pstrs.join(", "));
                md.push_str(&format!(") -> {}\n```\n", m.r#return));
                md.push_str(&format!("**method** `{}::{}`", type_name, m.name));
                if m.r#return != "void" { md.push_str(&format!(" → `{}`", m.r#return)); }
                if !m.doc.is_empty() { md.push_str(&format!("\n\n{}", m.doc)); }
                if !m.params.is_empty() {
                    md.push_str("\n\n**Parameters:**\n");
                    for p in &m.params { md.push_str(&format!("- `{}: {}`\n", p.name, p.r#type)); }
                }
            }
        }
    }
    for (type_name, mt) in &db.math_types {
        for m in &mt.methods {
            if m.name == method_name {
                md.push_str(&format!("```enma\n{}.{}(", type_name, m.name));
                let pstrs: Vec<String> = m.params.iter().map(|p| format!("{}: {}", p.name, p.r#type)).collect();
                md.push_str(&pstrs.join(", "));
                md.push_str(&format!(") -> {}\n```\n", m.r#return));
                md.push_str(&format!("**method** `{}::{}`", type_name, m.name));
                if m.r#return != "void" { md.push_str(&format!(" → `{}`", m.r#return)); }
                if !m.doc.is_empty() { md.push_str(&format!("\n\n{}", m.doc)); }
                if !m.params.is_empty() {
                    md.push_str("\n\n**Parameters:**\n");
                    for p in &m.params { md.push_str(&format!("- `{}: {}`\n", p.name, p.r#type)); }
                }
            }
        }
    }
    md
}

/// Type database hover for bare identifiers — functions, types, primitives, keywords.
/// Does NOT search methods (methods only fire for .access context).
fn format_type_db_hover_bare(db: &TypeDatabase, name: &str) -> String {
    format_type_db_hover_inner(db, name, false)
}

fn format_type_db_hover(db: &TypeDatabase, name: &str) -> String {
    format_type_db_hover_inner(db, name, true)
}

fn format_type_db_hover_inner(db: &TypeDatabase, name: &str, include_methods: bool) -> String {
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

    if include_methods {
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

#[derive(Debug)]
enum HoverContext {
    /// Preceded by `.` — identifier is a method/property name on a receiver.
    /// Contains the receiver's text if we can extract it.
    MethodAccess { receiver: Option<String> },
    /// Bare identifier — could be variable, function, type, or keyword reference.
    BareIdentifier,
}

/// Detect what kind of token we're hovering over by looking at the source text around it.
fn detect_context(node: tree_sitter::Node, source: &str) -> HoverContext {
    let byte = node.start_byte();
    if byte > 0 {
        let before = &source[..byte];
        // Look for ".identifier" — method access
        if let Some(dot_pos) = before.rfind('.') {
            let between = &before[dot_pos + 1..];
            if between.trim().is_empty() {
                let before_dot = &before[..dot_pos].trim_end();
                // Strip trailing subscript expressions: cs[0] → cs, arr[1][2] → arr
                let base = if let Some(bracket_pos) = before_dot.rfind('[') {
                    before_dot[..bracket_pos].trim_end().to_string()
                } else {
                    before_dot.to_string()
                };
                // Extract the last identifier-like token
                let receiver = base
                    .rsplit(|c: char| !c.is_alphanumeric() && c != '_')
                    .next()
                    .unwrap_or("")
                    .to_string();
                return HoverContext::MethodAccess {
                    receiver: if receiver.is_empty() { None } else { Some(receiver) },
                };
            }
        }
    }
    HoverContext::BareIdentifier
}

/// Find a local symbol and return its declared type name (var_type for variables/params,
/// name for struct/class/enum). Used to resolve receiver types for method calls.
/// Strip generic parameters and array brackets from a type name.
/// "array<window_info_t>" → "array", "int64[]" → "int64", "map<string,int64>" → "map"
fn normalize_type_name(type_name: &str) -> &str {
    let s = type_name;
    // Strip trailing [] (array brackets)
    let s = s.trim_end_matches("[]");
    // Strip generic parameters <...>
    if let Some(pos) = s.find('<') {
        &s[..pos]
    } else {
        s
    }
}

fn resolve_type_of_name(name: &str, model: &SemanticModel, _pos: Position) -> Option<String> {
    // Look for a symbol matching this name anywhere in the file
    for sym in &model.symbols {
        if sym.name == name {
            match sym.kind {
                semantic::SymbolKind::Variable | semantic::SymbolKind::Parameter => {
                    // Normalize the type: array<window_info_t> → array, int64[] → int64
                    return sym.var_type.as_ref().map(|t| normalize_type_name(t).to_string());
                }
                semantic::SymbolKind::Struct | semantic::SymbolKind::Class |
                semantic::SymbolKind::Enum | semantic::SymbolKind::Interface => {
                    return Some(sym.name.clone());
                }
                _ => {}
            }
        }
    }
    None
}

/// Standalone hover resolution — testable without the LSP server.
/// Returns (markdown_string, resolution_path) or None.
fn resolve_hover(
    name: &str,
    pos: Position,
    is_ident: bool,
    ctx: &HoverContext,
    model: &SemanticModel,
    db: &TypeDatabase,
) -> Option<(String, String)> {
    // ── Method access context (.name) ──
    if let HoverContext::MethodAccess { receiver } = ctx {
        // Try to resolve the receiver's type from local symbols
        let receiver_type = receiver.as_ref()
            .and_then(|r| resolve_type_of_name(r, model, pos));

        // Search methods — if we know the receiver type, only search that type.
        // Try the resolved type name first; if no methods found, also try
        // the raw receiver name in case it IS a type name (e.g., struct instances).
        let method_md = if let Some(ref rt) = receiver_type {
            let md = format_method_hover_for_type(db, name, rt);
            if !md.is_empty() { md }
            else {
                // Type not in DB — check if it's a custom struct/class in the model
                let custom = format_custom_struct_method(model, name, rt);
                if !custom.is_empty() { custom }
                else { format_method_hover_all(db, name) }
            }
        } else {
            // No receiver type resolved — try the receiver name directly as a type
            if let Some(ref recv) = receiver {
                let md = format_method_hover_for_type(db, name, recv);
                if !md.is_empty() { md }
                else {
                    let custom = format_custom_struct_method(model, name, recv);
                    if !custom.is_empty() { custom }
                    else { format_method_hover_all(db, name) }
                }
            } else {
                format_method_hover_all(db, name)
            }
        };

        if !method_md.is_empty() {
            let path = if receiver_type.is_some() {
                format!("method on {}", receiver_type.unwrap())
            } else {
                "method (all types)".into()
            };
            return Some((method_md, path));
        }
        // Method not found — fall through to try other lookups
    }

    // ── Local symbol lookup (only for identifiers) ──
    if is_ident {
        // Step 1: declaration-site
        let decl_match = model.symbols.iter()
            .filter(|s| s.name == name && range_contains(&s.range, pos))
            .min_by_key(|s| {
                let lines = (s.range.end.line - s.range.start.line) as u64;
                let chars = s.range.end.character.abs_diff(s.range.start.character) as u64;
                lines * 1000 + chars
            });
        if let Some(sym) = decl_match {
            let md = format_local_symbol_hover(sym);
            if !md.is_empty() {
                return Some((md, format!("decl-site {:?}", sym.kind)));
            }
        }

        // Step 2: reference-site — find the definition. Variables ALWAYS win over
        // same-named methods because we search local symbols BEFORE type DB methods.
        let ref_match = model.symbols.iter()
            .filter(|s| s.name == name && !range_contains(&s.range, pos))
            .max_by_key(|s| match s.kind {
                semantic::SymbolKind::Function => 5,
                semantic::SymbolKind::Struct => 4,
                semantic::SymbolKind::Class => 4,
                semantic::SymbolKind::Enum => 4,
                semantic::SymbolKind::Interface => 3,
                semantic::SymbolKind::Namespace => 2,
                semantic::SymbolKind::Variable => 1,
                semantic::SymbolKind::Parameter => 0,
                semantic::SymbolKind::TypeAlias => 2,
            });
        if let Some(sym) = ref_match {
            let def_md = format_local_symbol_hover(sym);
            if !def_md.is_empty() {
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
                let md = format!("*reference to {}*\n\n{}", kind_str, def_md);
                return Some((md, format!("ref-site {:?}", sym.kind)));
            }
        }
    }

    // ── Type database fallback ──
    // For bare identifiers (not method access): search functions, types, keywords.
    // Methods are NOT searched for bare identifiers — prevents variable names
    // from matching same-named methods.
    match ctx {
        HoverContext::BareIdentifier => {
            let db_md = format_type_db_hover_bare(db, name);
            if !db_md.is_empty() {
                return Some((db_md, "type-db".into()));
            }
        }
        HoverContext::MethodAccess { .. } => {
            // If specific type method search failed, try broad search
            let db_md = format_method_hover_all(db, name);
            if !db_md.is_empty() {
                return Some((db_md, "type-db-method".into()));
            }
            // Also try functions/types for chained calls like get_all_hwnds().something
            let db_md2 = format_type_db_hover_bare(db, name);
            if !db_md2.is_empty() {
                return Some((db_md2, "type-db".into()));
            }
        }
    }

    None
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

#[cfg(test)]
mod tests {
    use super::*;
    use tower_lsp::lsp_types::Position;

    fn setup_test(source: &str) -> (SemanticModel, TypeDatabase) {
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(tree.root_node(), source, &db);
        (model, db)
    }

    #[test]
    fn test_resolve_hover_custom_function_at_call_site() {
        let source = r#"void check(string label, bool ok) {
    println(label);
}

int64 main() {
    check("test", true);
    return 0;
}
"#;
        let (model, db) = setup_test(source);
        // Hover over 'check' in check("test", true) — line 5, char position on 'check'
        let call_pos = Position { line: 5, character: 4 }; // 'c' in 'check'
        let result = resolve_hover("check", call_pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some(), "FAIL: resolve_hover returned None for 'check' at call site. Symbols: {:?}",
            model.symbols.iter().map(|s| format!("{}:{:?}", s.name, s.kind)).collect::<Vec<_>>());
        let (md, path) = result.unwrap();
        assert!(path.contains("ref-site"), "FAIL: expected ref-site resolution, got '{}'", path);
        assert!(md.contains("check"), "FAIL: markdown doesn't contain 'check'");
        assert!(md.contains("label"), "FAIL: markdown doesn't mention param 'label'");
        assert!(md.contains("ok"), "FAIL: markdown doesn't mention param 'ok'");
        eprintln!("PASS: custom function at call site -> {}", path);
    }

    #[test]
    fn test_resolve_hover_custom_function_at_definition() {
        let source = r#"void check(string label, bool ok) {
    println(label);
}

int64 main() {
    check("test", true);
    return 0;
}
"#;
        let (model, db) = setup_test(source);
        // Hover over 'check' in definition — line 0
        let def_pos = Position { line: 0, character: 5 };
        let result = resolve_hover("check", def_pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some(), "FAIL: resolve_hover returned None for 'check' at definition");
        let (md, path) = result.unwrap();
        assert!(path.contains("decl-site"), "FAIL: expected decl-site, got '{}'", path);
        eprintln!("PASS: custom function at definition -> {}", path);
    }

    #[test]
    fn test_resolve_hover_builtin_type() {
        let source = r#"int64 main() {
    window_info_t info;
    return 0;
}
"#;
        let (model, db) = setup_test(source);
        // Hover over 'window_info_t'
        let pos = Position { line: 1, character: 4 };
        let result = resolve_hover("window_info_t", pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some(), "FAIL: resolve_hover returned None for 'window_info_t'. is_type={}",
            db.is_type("window_info_t"));
        let (md, path) = result.unwrap();
        eprintln!("PASS: window_info_t -> {} ({} chars)", path, md.len());
    }

    #[test]
    fn test_resolve_hover_array_type() {
        let source = r#"int64 main() {
    int64[] arr;
    return 0;
}
"#;
        let (model, db) = setup_test(source);
        // Hover over 'int64[]' — the '[' after int64. We test hovering over int64 which IS a primitive.
        let pos = Position { line: 1, character: 4 };
        // find_named_leaf would return "int64" identifier in "int64[]" type
        let result = resolve_hover("int64", pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some(), "FAIL: int64 primitive not resolved");
        eprintln!("PASS: int64 primitive resolved");
    }

    #[test]
    fn test_resolve_hover_method_name() {
        // Method names like 'length' should be found via type DB method search
        let source = r#"int64 main() {
    string s = "hello";
    int64 n = s.length();
    return n;
}
"#;
        let (model, db) = setup_test(source);
        // Hover over 'length' in s.length()
        let pos = Position { line: 2, character: 16 };
        // 'length' is accessed as s.length() — it's a method access on receiver 's' (type string)
        let ctx = HoverContext::MethodAccess { receiver: Some("s".into()) };
        let result = resolve_hover("length", pos, true, &ctx, &model, &db);
        assert!(result.is_some(), "FAIL: 'length' method not resolved");
        let (md, path) = result.unwrap();
        assert!(path.contains("method on string"), "FAIL: should resolve to method on string, got: {}", path);
        assert!(md.contains("string::length"), "FAIL: should show string::length, got: {}", md);
        eprintln!("PASS: method 'length' resolved for string type specifically");
    }

    #[test]
    fn test_variable_over_method_priority() {
        // A variable named 'first' should show variable hover, NOT method hover
        // (even though 'first' is also a method on array/list types)
        let source = r#"int64 main() {
    int64 first = 42;
    int64 result = first + 1;
    return result;
}
"#;
        let (model, db) = setup_test(source);
        // Hover over 'first' at a use site (first + 1)
        let pos = Position { line: 2, character: 18 };
        let result = resolve_hover("first", pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some(), "FAIL: variable 'first' not resolved");
        let (md, path) = result.unwrap();
        // IMPORTANT: should resolve as ref-site Variable, NOT as a method
        assert!(path.contains("Variable"), "FAIL: should find variable 'first', got path: {}", path);
        assert!(md.contains("first"), "FAIL: markdown should mention 'first'");
        assert!(md.contains("int64"), "FAIL: should show int64 type for variable 'first'");
        // Make sure it does NOT show method info from type DB
        assert!(!path.contains("method"), "FAIL: should NOT resolve via method search, got: {}", path);
        eprintln!("PASS: variable 'first' resolves as variable, not method (path: {})", path);
    }

    #[test]
    fn test_method_on_specific_receiver_type() {
        // v.length() — hovering over 'length' on a string variable should show string::length
        let source = r#"int64 main() {
    string name = "hello";
    int64 len = name.length();
    return len;
}
"#;
        let (model, db) = setup_test(source);
        // Hover over 'length' in name.length()
        let pos = Position { line: 2, character: 18 };
        let ctx = HoverContext::MethodAccess { receiver: Some("name".into()) };
        let result = resolve_hover("length", pos, true, &ctx, &model, &db);
        assert!(result.is_some(), "FAIL: 'length' method not resolved");
        let (md, path) = result.unwrap();
        // Should resolve specifically to string.length
        assert!(md.contains("string::length") || md.contains("string.length"),
            "FAIL: should show string::length specifically, got path={}, md={}", path, md);
        // Should NOT list length methods from multiple types
        let length_count = md.matches("::length").count();
        assert!(length_count <= 2, "FAIL: too many 'length' method listings ({}), should be string-specific.\nMarkdown:\n{}", length_count, md);
        eprintln!("PASS: method 'length' resolved for string type specifically (path: {})", path);
    }

    #[test]
    fn test_generic_type_method_resolution() {
        // array<window_info_t> wins = ...; wins.length() → should show array::length ONLY
        let source = r#"int64 main() {
    array<window_info_t> wins;
    int64 n = wins.length();
    return n;
}
"#;
        let (model, db) = setup_test(source);
        // Hover over 'length' in wins.length()
        let pos = Position { line: 2, character: 18 };
        let ctx = HoverContext::MethodAccess { receiver: Some("wins".into()) };
        let result = resolve_hover("length", pos, true, &ctx, &model, &db);
        assert!(result.is_some(), "FAIL: 'length' method on wins not resolved. Symbols: {:?}",
            model.symbols.iter().map(|s| format!("{}:{:?}", s.name, s.kind)).collect::<Vec<_>>());
        let (md, path) = result.unwrap();
        // Should resolve specifically to array.length
        assert!(md.contains("array::length") || md.contains("array.length"),
            "FAIL: should show array::length for generic array<window_info_t>, got path={}, md={}", path, md);
        // Should NOT list length from every other type
        let count = md.matches("::length").count();
        assert!(count <= 2, "FAIL: too many length listings ({}), should only be array::length.\nMD:\n{}", count, md);
        eprintln!("PASS: generic type array<window_info_t> method length → array::length (path: {})", path);
    }

    #[test]
    fn test_normalize_type_name() {
        assert_eq!(normalize_type_name("array<window_info_t>"), "array");
        assert_eq!(normalize_type_name("map<string,int64>"), "map");
        assert_eq!(normalize_type_name("int64[]"), "int64");
        assert_eq!(normalize_type_name("string[][]"), "string");
        assert_eq!(normalize_type_name("window_info_t"), "window_info_t");
        assert_eq!(normalize_type_name("vec3"), "vec3");
        eprintln!("PASS: type name normalization works correctly");
    }

    #[test]
    fn test_window_info_t_first_method_pid() {
        // window_info_t first = ...; first.pid() → should show ONLY window_info_t::pid
        let source = r#"int64 main() {
    window_info_t first;
    int64 p = first.pid();
    return p;
}
"#;
        let (model, db) = setup_test(source);
        // Debug: show all collected symbols
        eprintln!("Symbols in model:");
        for sym in &model.symbols {
            eprintln!("  {:?} name='{}' var_type={:?} range={}:{}..{}:{}",
                sym.kind, sym.name, sym.var_type,
                sym.range.start.line, sym.range.start.character,
                sym.range.end.line, sym.range.end.character);
        }
        // Hover over 'pid' in first.pid()
        let pos = Position { line: 2, character: 20 };
        let ctx = HoverContext::MethodAccess { receiver: Some("first".into()) };
        let result = resolve_hover("pid", pos, true, &ctx, &model, &db);
        assert!(result.is_some(), "FAIL: 'pid' method on first not resolved");
        let (md, path) = result.unwrap();
        eprintln!("Path: {}", path);
        eprintln!("Markdown:\n{}", md);
        // Should resolve specifically to window_info_t.pid, NOT proc_t.pid
        assert!(md.contains("window_info_t::pid") || md.contains("window_info_t.pid"),
            "FAIL: should show window_info_t::pid, got path={} md={}", path, md);
        // Should NOT show proc_t.pid
        let proc_count = md.matches("proc_t::pid").count();
        assert_eq!(proc_count, 0, "FAIL: should NOT show proc_t::pid, got {} occurrences.\nMD:\n{}", proc_count, md);
        // Should only show ONE type's pid method
        let total_pid = md.matches("::pid").count();
        assert!(total_pid <= 2, "FAIL: too many pid listings ({}), should be window_info_t-specific.\nMD:\n{}", total_pid, md);
        eprintln!("PASS: first.pid() resolves to window_info_t::pid ONLY (path: {})", path);
    }

    #[test]
    fn test_custom_struct_method_hover() {
        // Simulates: Cell c1; c1.inc(); → should show Cell::inc(), not atomic_int64::inc()
        let source = r#"struct Cell {
    int32 v;
    Cell() { this->v = 0; }
    void inc() { this->v = this->v + 1; }
}

int64 main() {
    Cell c1;
    c1.inc();
    return 0;
}
"#;
        let (model, db) = setup_test(source);
        eprintln!("Symbols in model:");
        for sym in &model.symbols {
            eprintln!("  {:?} '{}' methods={} var_type={:?}",
                sym.kind, sym.name, sym.methods.len(), sym.var_type);
            for m in &sym.methods {
                eprintln!("    method: {}()", m.name);
            }
        }

        // Hover over 'inc' in c1.inc()
        let pos = Position { line: 8, character: 7 };
        let ctx = HoverContext::MethodAccess { receiver: Some("c1".into()) };
        let result = resolve_hover("inc", pos, true, &ctx, &model, &db);
        assert!(result.is_some(), "FAIL: 'inc' method not resolved at all");
        let (md, path) = result.unwrap();
        eprintln!("Path: {}", path);
        eprintln!("Markdown:\n{}", md);

        // Should show Cell::inc, NOT atomic_int64::inc
        assert!(md.contains("Cell::inc") || md.contains("Cell.inc"),
            "FAIL: should show Cell::inc, got path={} md={}", path, md);
        let atomic = md.matches("atomic").count();
        assert_eq!(atomic, 0, "FAIL: should NOT mention atomic methods, got {} occurrences.\nMD:\n{}", atomic, md);
        eprintln!("PASS: custom struct method hover works correctly");
    }

    #[test]
    fn test_imported_struct_method_merge() {
        // Simulate imported struct: build lib model, merge into main model
        let lib_source = r#"struct Cell {
    int32 v;
    Cell() { this->v = 0; }
    void inc() { this->v = this->v + 1; }
}
"#;
        let main_source = r#"int64 main() {
    Cell c1;
    c1.inc();
    return 0;
}
"#;
        let (lib_model, _) = setup_test(lib_source);
        let (mut main_model, db) = setup_test(main_source);
        eprintln!("Before merge: {} symbols", main_model.symbols.len());
        main_model.merge_import(lib_model, "lib.em");
        eprintln!("After merge: {} symbols", main_model.symbols.len());
        for sym in &main_model.symbols {
            eprintln!("  {:?} '{}' methods={} var_type={:?}",
                sym.kind, sym.name, sym.methods.len(), sym.var_type);
        }

        // Hover over 'inc' in c1.inc()
        let pos = Position { line: 2, character: 7 };
        let ctx = HoverContext::MethodAccess { receiver: Some("c1".into()) };
        let result = resolve_hover("inc", pos, true, &ctx, &main_model, &db);
        assert!(result.is_some(), "FAIL: 'inc' on imported struct not resolved");
        let (md, path) = result.unwrap();
        eprintln!("Path: {}", path);
        assert!(md.contains("Cell::inc") || md.contains("Cell.inc"),
            "FAIL: should show Cell::inc from imported struct, got: {}", md);
        let atomic = md.matches("atomic").count();
        assert_eq!(atomic, 0, "FAIL: should NOT mention atomic methods");
        eprintln!("PASS: imported struct method hover works after merge");
    }

    #[test]
    fn test_bare_identifier_never_shows_methods() {
        // A bare identifier (not preceded by .) should NEVER match type methods,
        // even if the name happens to be a common method name
        let source = r#"int64 main() {
    int64 length = 10;
    return length;
}
"#;
        let (model, db) = setup_test(source);
        // Hover over 'length' at use site — it's a variable, NOT a method call
        let pos = Position { line: 2, character: 11 };
        let result = resolve_hover("length", pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some(), "FAIL: variable 'length' not resolved");
        let (md, path) = result.unwrap();
        // Must find the variable, not the string.length / array.length / etc. methods
        assert!(path.contains("Variable"), "FAIL: should find variable 'length', got: {}", path);
        assert!(!md.contains("string::length") && !md.contains("array::length") && !md.contains("method"),
            "FAIL: bare identifier 'length' should NOT show method info, got: {}", md);
        eprintln!("PASS: bare 'length' resolves as variable, not method");
    }
}
