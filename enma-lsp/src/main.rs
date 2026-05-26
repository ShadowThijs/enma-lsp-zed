mod parser;
mod type_db;
mod completion;
mod semantic;
mod hover;

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
                            None => eprintln!("[hover] NO MATCH - func={} type={} prim={} kw={}",
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
            if let Some(model) = self.build_model_with_imports(source, &uri).await {
                let mut parser = self.parser.lock().await;
                if let Some(tree) = parser.parse(source.as_bytes()) {
                    let node = find_named_leaf(tree.root_node(), pos);
                    if node.kind() == "identifier" {
                        let name = &source[node.start_byte()..node.end_byte()];
                        for sym in &model.symbols {
                            if sym.name == name && !range_contains(&sym.range, pos) {
                                return Ok(Some(GotoDefinitionResponse::Scalar(Location {
                                    uri: uri.clone(),
                                    range: sym.range,
                                })));
                            }
                        }
                        for sym in &model.symbols {
                            for m in &sym.methods {
                                if m.name == name && !range_contains(&m.range, pos) {
                                    return Ok(Some(GotoDefinitionResponse::Scalar(Location {
                                        uri: uri.clone(),
                                        range: m.range,
                                    })));
                                }
                            }
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
                    };
                    #[allow(deprecated)]
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
    /// Handles both relative paths (joined with base_dir) and absolute paths (used directly).
    fn load_file_from_disk(base_dir: &std::path::Path, import_path: &str) -> Option<String> {
        // Detect absolute paths: Unix (/...), Windows (C:\... or C:/...)
        let is_absolute = import_path.starts_with('/')
            || (import_path.len() >= 3
                && import_path.as_bytes()[1] == b':'
                && (import_path.as_bytes()[2] == b'/' || import_path.as_bytes()[2] == b'\\'));
        let full = if is_absolute {
            std::path::PathBuf::from(import_path)
        } else {
            base_dir.join(import_path)
        };
        let full_em = if is_absolute {
            std::path::PathBuf::from(format!("{}.em", import_path))
        } else {
            base_dir.join(format!("{}.em", import_path))
        };
        if full.exists() {
            std::fs::read_to_string(&full).ok()
        } else {
            std::fs::read_to_string(&full_em).ok()
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

    async fn publish_diagnostics(&self, uri: &Url, text: &str) {
        let mut parser = self.parser.lock().await;
        let tree = parser.parse(text.as_bytes());

        let diagnostics = if let Some(tree) = &tree {
            let mut diags = self.collect_syntax_errors(tree.root_node(), text);
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
            diags.extend(model.diagnostics.clone());
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
        source: &str,
    ) -> Vec<Diagnostic> {
        let mut results = Vec::new();

        if node.is_error() || node.is_missing() {
            if node.child_count() == 0 {
                // GLR parser may produce leaf ERROR nodes for valid tokens
                // (numbers, identifiers) when a wrong parse branch is taken.
                // Only report if the text looks like a genuine syntax error.
                let text = &source[node.start_byte()..node.end_byte()];
                let is_glr_artifact = text.chars().all(|c| {
                    c.is_alphanumeric() || c == '_' || c == '.' || c == 'f' || c == 'x' || c == 'X'
                }) || text.trim().is_empty();
                if !is_glr_artifact {
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
        }

        let mut cursor = node.walk();
        for child in node.children(&mut cursor) {
            results.extend(self.collect_syntax_errors(child, source));
        }

        results
    }
}

use hover::*;

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
