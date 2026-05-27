//! CLI test tool for enma-lsp. Runs the semantic model against .em files
//! and prints all diagnostics, symbols, and hover info.
//!
//! Usage: cargo run --bin test-lsp -- <file.em> [<file2.em> ...]
//!        cargo run --bin test-lsp -- --dir ../examples

mod parser;
mod type_db;
mod semantic;
mod hover;
mod bundler;

use type_db::TypeDatabase;
use semantic::SemanticModel;
use hover::*;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;

static TYPE_DB: OnceLock<TypeDatabase> = OnceLock::new();

fn get_db() -> &'static TypeDatabase {
    TYPE_DB.get_or_init(TypeDatabase::load)
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: test-lsp <file.em> [<file2.em> ...]");
        eprintln!("       test-lsp --dir <directory>");
        eprintln!("       test-lsp --bundle <file.em> [--strip-comments] [--output <path>]");
        std::process::exit(1);
    }

    // ── Bundle mode ──
    if args[1] == "--bundle" && args.len() >= 3 {
        let entry = PathBuf::from(&args[2]);
        let strip = args.iter().any(|a| a == "--strip-comments");
        let output = args
            .iter()
            .position(|a| a == "--output")
            .and_then(|i| args.get(i + 1));

        let opts = bundler::BundleOptions {
            strip_comments: strip,
        };

        match bundler::bundle(&entry, &opts) {
            Ok(result) => {
                for w in &result.warnings {
                    eprintln!("[bundle] WARNING: {}", w);
                }
                if let Some(path) = output {
                    if Path::new(path).exists() {
                        eprintln!("[bundle] ERROR: output file already exists: {}", path);
                        std::process::exit(1);
                    }
                    if let Some(parent) = Path::new(path).parent() {
                        let _ = std::fs::create_dir_all(parent);
                    }
                    if let Err(e) = std::fs::write(path, &result.source) {
                        eprintln!("[bundle] ERROR writing output: {}", e);
                        std::process::exit(1);
                    }
                    eprintln!("[bundle] Wrote {} bytes to {}", result.source.len(), path);
                } else {
                    println!("{}", result.source);
                }
            }
            Err(e) => {
                eprintln!("[bundle] ERROR: {}", e);
                std::process::exit(1);
            }
        }
        return;
    }

    let db = get_db();
    let mut files = Vec::new();

    if args[1] == "--dir" && args.len() >= 3 {
        let dir = &args[2];
        let entries = std::fs::read_dir(dir).expect("read_dir failed");
        for entry in entries {
            let entry = entry.unwrap();
            let path = entry.path();
            if path.extension().map_or(false, |e| e == "em") {
                files.push(path.clone());
            }
            if path.is_dir() {
                // Walk subdirectories
                if let Ok(sub) = std::fs::read_dir(&path) {
                    for e in sub {
                        let e = e.unwrap();
                        if e.path().extension().map_or(false, |ext| ext == "em") {
                            files.push(e.path());
                        }
                    }
                }
            }
        }
    } else {
        for arg in &args[1..] {
            files.push(PathBuf::from(arg));
        }
    }

    files.sort();

    let mut parser = parser::EnmaParser::new().expect("parser init");

    for file in &files {
        println!("\n{}", "=".repeat(80));
        println!("FILE: {}", file.display());
        println!("{}", "=".repeat(80));

        let source = match std::fs::read_to_string(&file) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("  ERROR reading file: {}", e);
                continue;
            }
        };

        let tree = match parser.parse(source.as_bytes()) {
            Some(t) => t,
            None => {
                eprintln!("  ERROR: parse failed");
                continue;
            }
        };

        let root = tree.root_node();
        let mut model = SemanticModel::build(root, &source, db);

        // Resolve imports from disk
        let base_dir = file.parent().unwrap_or(std::path::Path::new("."));
        let imports = model.imports.clone();
        for import_path in &imports {
            let full = base_dir.join(import_path);
            let import_source = std::fs::read_to_string(&full)
                .or_else(|_| std::fs::read_to_string(base_dir.join(format!("{}.em", import_path))));
            if let Ok(ref import_source) = import_source {
                if let Some(import_tree) = parser.parse(import_source.as_bytes()) {
                    let import_model = SemanticModel::build(import_tree.root_node(), import_source, db);
                    eprintln!("  [import] merged {} ({} symbols)", import_path, import_model.symbols.len());
                    model.merge_import(import_model, import_path);
                }
            } else {
                eprintln!("  [import] FAILED: {}", import_path);
            }
        }

        // ── Symbols ──
        println!("\n[SYMBOLS] {} total", model.symbols.len());
        for sym in &model.symbols {
            let kind = match sym.kind {
                semantic::SymbolKind::Function => "FUNC",
                semantic::SymbolKind::Variable => "VAR",
                semantic::SymbolKind::Parameter => "PARAM",
                semantic::SymbolKind::Struct => "STRUCT",
                semantic::SymbolKind::Class => "CLASS",
                semantic::SymbolKind::Enum => "ENUM",
                semantic::SymbolKind::Interface => "IFACE",
                semantic::SymbolKind::Namespace => "NS",
            };
            println!("  [{kind}] '{}' @ L{}:C{}  type={:?}  var_type={:?}  ret={:?}  fields={}  methods={}  owner={:?}",
                sym.name,
                sym.range.start.line, sym.range.start.character,
                sym.type_name, sym.var_type, sym.return_type,
                sym.fields.len(), sym.methods.len(),
                sym.owner_type);
            for f in &sym.fields {
                println!("      field: {}: {:?}", f.name, f.field_type);
            }
            for m in &sym.methods {
                println!("      method: {}() -> {:?}", m.name, m.return_type);
            }
        }

        // ── Diagnostics ──
        println!("\n[DIAGNOSTICS] {} total", model.diagnostics.len());
        for d in &model.diagnostics {
            let severity = match d.severity {
                Some(tower_lsp::lsp_types::DiagnosticSeverity::ERROR) => "ERROR",
                Some(tower_lsp::lsp_types::DiagnosticSeverity::WARNING) => "WARN",
                _ => "INFO",
            };
            println!("  [{severity}] L{}:C{}  {}",
                d.range.start.line, d.range.start.character, d.message);
        }

        // ── Hover tests for all identifiers ──
        println!("\n[HOVER] Testing all identifiers...");
        let mut hover_count = 0;
        let mut hover_errors = 0;
        find_all_identifiers(root, &source, &mut |node: tree_sitter::Node, text: &str| {
            let pos = tower_lsp::lsp_types::Position {
                line: node.start_position().row as u32,
                character: node.start_position().column as u32,
            };
            let ctx = detect_context(node, &source);
            let is_ident = node.kind() == "identifier";
            let result = resolve_hover(text, pos, is_ident, &ctx, &model, db);

            match &ctx {
                HoverContext::MethodAccess { receiver } => {
                    print!("  .{} @ L{}:C{}", text, pos.line, pos.character);
                    if let Some(ref recv) = receiver {
                        print!("  receiver='{}'", recv);
                    }
                }
                HoverContext::BareIdentifier => {
                    print!("  {} @ L{}:C{}", text, pos.line, pos.character);
                }
            }

            match &result {
                Some((_, path)) => {
                    println!("  => {}", path);
                    hover_count += 1;
                }
                None => {
                    println!("  => NONE");
                    hover_errors += 1;
                }
            }
        });
        println!("  Resolved: {}, Unresolved: {}", hover_count, hover_errors);

        // ── Imports ──
        if !model.imports.is_empty() {
            println!("\n[IMPORTS] {} imports:", model.imports.len());
            for imp in &model.imports {
                println!("  {}", imp);
            }
        }
    }
}

fn find_all_identifiers(node: tree_sitter::Node, source: &str, f: &mut dyn FnMut(tree_sitter::Node, &str)) {
    if node.child_count() == 0 && node.kind() == "identifier" {
        let text = &source[node.start_byte()..node.end_byte()];
        f(node, text);
    }
    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        find_all_identifiers(child, source, f);
    }
}
