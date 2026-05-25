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
                for sym in &model.symbols {
                    if range_contains(&sym.range, pos) {
                        let type_info = sym.type_name.as_deref().unwrap_or("unknown");
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
                        return Ok(Some(Hover {
                            contents: HoverContents::Scalar(
                                MarkedString::String(format!("{} {}: {}", kind_str, sym.name, type_info))
                            ),
                            range: Some(sym.range),
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
