//! Semantic analysis: symbol collection, scope tree, type checking.
//! Walks the tree-sitter parse tree to extract declarations and check types.

use crate::type_db::TypeDatabase;
use std::collections::HashMap;
use tower_lsp::lsp_types::{Diagnostic, DiagnosticSeverity, NumberOrString, Position, Range};

/// A symbol declaration found in the source.
#[derive(Debug, Clone)]
pub struct Symbol {
    pub name: String,
    pub kind: SymbolKind,
    pub range: Range,
    pub type_name: Option<String>,
    /// For structs/classes: the fields declared in this type.
    pub fields: Vec<FieldInfo>,
    /// For structs/classes: the methods declared in this type.
    pub methods: Vec<MethodInfo2>,
    /// For variables: the declared variable type (extracted from the AST).
    pub var_type: Option<String>,
    /// For functions: parameter list.
    pub params: Vec<(String, Option<String>)>,
    /// For functions: return type.
    pub return_type: Option<String>,
    /// For enums: variant names.
    pub enum_variants: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct FieldInfo {
    pub name: String,
    pub field_type: Option<String>,
}

#[derive(Debug, Clone)]
pub struct MethodInfo2 {
    pub name: String,
    pub return_type: Option<String>,
    pub params: Vec<(String, Option<String>)>,
    pub range: Range,
}

#[derive(Debug, Clone, PartialEq)]
pub enum SymbolKind {
    Function,
    Variable,
    Parameter,
    Struct,
    Class,
    Enum,
    Interface,
    Namespace,
    TypeAlias,
}

/// The semantic model for a file: all symbols, their scopes, and any type errors.
#[derive(Debug)]
pub struct SemanticModel {
    pub symbols: Vec<Symbol>,
    pub diagnostics: Vec<Diagnostic>,
}

impl SemanticModel {
    /// Build the semantic model from a tree-sitter tree + source text.
    pub fn build(root: tree_sitter::Node, source: &str, _db: &TypeDatabase) -> Self {
        let mut collector = SymbolCollector::new(source);
        collector.walk(root);
        let diagnostics = collector.check_type_errors();
        Self {
            symbols: collector.symbols,
            diagnostics,
        }
    }

    pub fn empty() -> Self {
        Self { symbols: Vec::new(), diagnostics: Vec::new() }
    }

    pub fn diagnostics(&self) -> Vec<Diagnostic> {
        self.diagnostics.clone()
    }
}

struct SymbolCollector<'a> {
    source: &'a str,
    symbols: Vec<Symbol>,
    /// Track variables in function scopes to detect re-declarations and type mismatches.
    scope_vars: Vec<HashMap<String, Symbol>>,
}

impl<'a> SymbolCollector<'a> {
    fn new(source: &'a str) -> Self {
        Self {
            source,
            symbols: Vec::new(),
            scope_vars: vec![HashMap::new()],
        }
    }

    fn push_scope(&mut self) {
        self.scope_vars.push(HashMap::new());
    }

    fn pop_scope(&mut self) {
        self.scope_vars.pop();
    }

    fn empty_symbol(name: String, kind: SymbolKind, range: Range) -> Symbol {
        Symbol {
            name,
            kind,
            range,
            type_name: None,
            fields: Vec::new(),
            methods: Vec::new(),
            var_type: None,
            params: Vec::new(),
            return_type: None,
            enum_variants: Vec::new(),
        }
    }

    fn add_symbol(&mut self, sym: Symbol) {
        if let Some(scope) = self.scope_vars.last_mut() {
            scope.insert(sym.name.clone(), sym.clone());
        }
        self.symbols.push(sym);
    }

    fn walk(&mut self, node: tree_sitter::Node) {
        match node.kind() {
            "function_definition" => self.collect_function(node),
            "function_declaration" => self.collect_function(node),
            "method_declaration" => self.collect_function(node),
            "struct_declaration" => self.collect_struct(node),
            "class_declaration" => self.collect_class(node),
            "enum_declaration" => self.collect_enum(node),
            "interface_declaration" => self.collect_interface(node),
            "namespace_definition" => self.collect_namespace(node),
            "global_variable_declaration" => self.collect_variable(node),
            "declaration_statement" => self.collect_variable(node),
            // expression_statement can contain variable-like declarations when the
            // grammar doesn't recognize a custom type name.
            "expression_statement" => {
                // Gather children info BEFORE borrowing self.source
                let mut cursor = node.walk();
                let child_info: Vec<_> = node.children(&mut cursor).map(|c| {
                    (c.kind().to_string(), c.start_byte(), c.end_byte(), c.child_count())
                }).collect();
                if child_info.len() >= 2 && child_info[0].0 == "identifier" {
                    let type_name = self.source[child_info[0].1..child_info[0].2].to_string();
                    let second = &child_info[1];
                    let name_opt = if second.0 == "identifier" {
                        Some(self.source[second.1..second.2].to_string())
                    } else if second.0 == "ERROR" && second.3 > 0 {
                        // The ERROR node wraps an identifier — extract text directly
                        let err_text = &self.source[second.1..second.2];
                        // Find the first identifier-like word
                        err_text.split_whitespace().next().map(|s| s.to_string())
                    } else {
                        None
                    };
                    if let Some(name) = name_opt {
                        let range = self.node_range(&node);
                        let mut sym = Self::empty_symbol(name, SymbolKind::Variable, range);
                        sym.var_type = Some(type_name.clone());
                        sym.type_name = Some(type_name);
                        self.add_symbol(sym);
                    }
                }
            }
            "parameter_declaration" => self.collect_parameter(node),
            "block" | "struct_body" | "class_body" => {
                self.push_scope();
                self.walk_children(node);
                self.pop_scope();
                return;
            }
            _ => {}
        }
        self.walk_children(node);
    }

    fn walk_children(&mut self, node: tree_sitter::Node) {
        let mut cursor = node.walk();
        for child in node.children(&mut cursor) {
            self.walk(child);
        }
    }

    fn collect_function(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        if let Some(name) = name {
            let range = self.node_range(&node);
            let return_type = self.child_text_by_field(node, "return_type");
            let params = self.extract_params(node);
            let mut sym = Self::empty_symbol(name.clone(), SymbolKind::Function, range);
            sym.return_type = return_type;
            sym.params = params;
            // type_name shows the full signature summary
            sym.type_name = Some(self.function_sig_summary(&name, &sym.return_type, &sym.params));
            self.add_symbol(sym);
        }
    }

    fn function_sig_summary(&self, name: &str, ret: &Option<String>, params: &[(String, Option<String>)]) -> String {
        let param_strs: Vec<String> = params.iter()
            .map(|(n, t)| {
                if let Some(ty) = t {
                    format!("{}: {}", n, ty)
                } else {
                    n.clone()
                }
            })
            .collect();
        let ret_str = ret.as_deref().unwrap_or("void");
        format!("fn {}({}) -> {}", name, param_strs.join(", "), ret_str)
    }

    fn extract_params(&self, node: tree_sitter::Node) -> Vec<(String, Option<String>)> {
        let mut params = Vec::new();
        let mut cursor = node.walk();
        for child in node.children(&mut cursor) {
            if child.kind() == "parameter_list" || child.kind() == "parameters" {
                let mut pc = child.walk();
                for p in child.children(&mut pc) {
                    if p.kind() == "parameter_declaration" || p.kind() == "optional_parameter_declaration" {
                        let pname = self.child_text_by_field(p, "name");
                        let ptype = self.child_text_by_field(p, "type");
                        if let Some(n) = pname {
                            params.push((n, ptype));
                        }
                    }
                }
            }
        }
        params
    }

    fn collect_struct(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        if let Some(name) = name {
            let range = self.node_range(&node);
            let mut sym = Self::empty_symbol(name.clone(), SymbolKind::Struct, range);
            self.extract_members(node, &mut sym);
            let field_count = sym.fields.len();
            let method_count = sym.methods.len();
            sym.type_name = Some(format!("struct ({} fields, {} methods)", field_count, method_count));
            self.add_symbol(sym);
        }
    }

    fn collect_class(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        if let Some(name) = name {
            let range = self.node_range(&node);
            let mut sym = Self::empty_symbol(name.clone(), SymbolKind::Class, range);
            self.extract_members(node, &mut sym);
            let field_count = sym.fields.len();
            let method_count = sym.methods.len();
            sym.type_name = Some(format!("class ({} fields, {} methods)", field_count, method_count));
            self.add_symbol(sym);
        }
    }

    fn extract_members(&mut self, node: tree_sitter::Node, sym: &mut Symbol) {
        let mut cursor = node.walk();
        for child in node.children(&mut cursor) {
            match child.kind() {
                "struct_body" | "class_body" => {
                    self.extract_members(child, sym);
                }
                "field_declaration" => {
                    let fname = self.child_text_by_field(child, "name");
                    let ftype = self.child_text_by_field(child, "type");
                    if let Some(n) = fname {
                        sym.fields.push(FieldInfo { name: n, field_type: ftype });
                    }
                }
                "method_declaration" => {
                    let mname = self.child_text_by_field(child, "name");
                    let rtype = self.child_text_by_field(child, "return_type");
                    if let Some(n) = mname {
                        let range = self.node_range(&child);
                        let mparams = self.extract_params(child);
                        sym.methods.push(MethodInfo2 {
                            name: n, return_type: rtype, params: mparams, range,
                        });
                    }
                }
                "constructor_declaration" => {
                    let cname = self.child_text_by_field(child, "name");
                    if let Some(n) = cname {
                        let range = self.node_range(&child);
                        sym.methods.push(MethodInfo2 {
                            name: n, return_type: None, params: Vec::new(), range,
                        });
                    }
                }
                "destructor_declaration" => {
                    // Destructors have a 'name' field with the class name prefixed by '~'
                    if let Some(dtor_name) = self.child_text_by_field(child, "name") {
                        let range = self.node_range(&child);
                        sym.methods.push(MethodInfo2 {
                            name: dtor_name, return_type: None, params: Vec::new(), range,
                        });
                    }
                }
                _ => {}
            }
        }
    }

    fn collect_enum(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        if let Some(name) = name {
            let range = self.node_range(&node);
            let mut sym = Self::empty_symbol(name.clone(), SymbolKind::Enum, range);
            // Extract enum variants
            let mut cursor = node.walk();
            for child in node.children(&mut cursor) {
                if child.kind() == "enum_body" {
                    let mut bc = child.walk();
                    for variant in child.children(&mut bc) {
                        if variant.kind() == "enumerator" {
                            if let Some(vname) = self.child_text_by_field(variant, "name") {
                                sym.enum_variants.push(vname);
                            }
                        }
                    }
                }
            }
            let variant_count = sym.enum_variants.len();
            sym.type_name = Some(format!("enum ({} variants)", variant_count));
            self.add_symbol(sym);
        }
    }

    fn collect_interface(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        if let Some(name) = name {
            let range = self.node_range(&node);
            self.add_symbol(Self::empty_symbol(name, SymbolKind::Interface, range));
        }
    }

    fn collect_namespace(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        if let Some(name) = name {
            let range = self.node_range(&node);
            self.add_symbol(Self::empty_symbol(name, SymbolKind::Namespace, range));
        }
    }

    fn collect_variable(&mut self, node: tree_sitter::Node) {
        let type_name = self.child_text_by_field(node, "type");
        // Try direct 'name' field first (parameter-style declarations)
        let direct_name = self.child_text_by_field(node, "name");
        if let Some(name) = direct_name {
            let range = self.node_range(&node);
            let mut sym = Self::empty_symbol(name.clone(), SymbolKind::Variable, range);
            sym.var_type = type_name.clone();
            sym.type_name = type_name.clone();
            self.add_symbol(sym);
            return;
        }
        // Try 'declarator' field (Enma grammar nests name inside init_declarator)
        if let Some(decl) = node.child_by_field_name("declarator") {
            let name = self.child_text_by_field(decl, "name");
            if let Some(name) = name {
                let range = self.node_range(&node);
                let mut sym = Self::empty_symbol(name.clone(), SymbolKind::Variable, range);
                sym.var_type = type_name.clone();
                sym.type_name = type_name.clone();
                self.add_symbol(sym);
            }
        } else {
            // Walk children to find init_declarator nodes
            let mut cursor = node.walk();
            for child in node.children(&mut cursor) {
                if child.kind() == "init_declarator" {
                    let name = self.child_text_by_field(child, "name");
                    if let Some(name) = name {
                        let range = self.node_range(&node);
                        let mut sym = Self::empty_symbol(name.clone(), SymbolKind::Variable, range);
                        sym.var_type = type_name.clone();
                        sym.type_name = type_name.clone();
                        self.add_symbol(sym);
                    }
                }
            }
        }
    }

    fn collect_parameter(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        let type_name = self.child_text_by_field(node, "type");
        if let Some(name) = name {
            let range = self.node_range(&node);
            let mut sym = Self::empty_symbol(name.clone(), SymbolKind::Parameter, range);
            sym.var_type = type_name.clone();
            sym.type_name = type_name;
            self.add_symbol(sym);
        }
    }

    /// Check for type errors in the collected symbols.
    fn check_type_errors(&self) -> Vec<Diagnostic> {
        let mut diags = Vec::new();

        // Check for duplicate definitions in the same scope
        for scope in &self.scope_vars {
            let mut seen: HashMap<&str, &Symbol> = HashMap::new();
            for sym in scope.values() {
                if let Some(prev) = seen.get(sym.name.as_str()) {
                    diags.push(Diagnostic {
                        range: sym.range,
                        severity: Some(DiagnosticSeverity::ERROR),
                        code: Some(NumberOrString::String("duplicate-definition".into())),
                        source: Some("enma-lsp".into()),
                        message: format!(
                            "Duplicate definition of '{}' (previously defined at line {})",
                            sym.name,
                            prev.range.start.line + 1
                        ),
                        ..Default::default()
                    });
                }
                seen.insert(&sym.name, sym);
            }
        }

        // Also check for duplicate top-level definitions (function/struct/class/enum)
        // by scanning ALL symbols regardless of scope, since scoping may miss some cases.
        let def_kinds = [SymbolKind::Function, SymbolKind::Struct, SymbolKind::Class,
                         SymbolKind::Enum, SymbolKind::Interface, SymbolKind::Namespace];
        for i in 0..self.symbols.len() {
            let sym = &self.symbols[i];
            if !def_kinds.contains(&sym.kind) { continue; }
            for j in (i+1)..self.symbols.len() {
                let other = &self.symbols[j];
                if !def_kinds.contains(&other.kind) { continue; }
                if sym.name == other.name && sym.kind == other.kind {
                    // Avoid duplicate diagnostics for the same pair
                    let already = diags.iter().any(|d| d.range == other.range);
                    if !already {
                        diags.push(Diagnostic {
                            range: other.range,
                            severity: Some(DiagnosticSeverity::ERROR),
                            code: Some(NumberOrString::String("duplicate-definition".into())),
                            source: Some("enma-lsp".into()),
                            message: format!(
                                "Duplicate {} '{}' (previously defined at line {})",
                                match sym.kind {
                                    SymbolKind::Function => "function",
                                    SymbolKind::Struct => "struct",
                                    SymbolKind::Class => "class",
                                    SymbolKind::Enum => "enum",
                                    SymbolKind::Interface => "interface",
                                    SymbolKind::Namespace => "namespace",
                                    _ => "symbol",
                                },
                                sym.name,
                                sym.range.start.line + 1
                            ),
                            ..Default::default()
                        });
                    }
                }
            }
        }

        diags
    }

    fn child_text_by_field(&self, node: tree_sitter::Node, field: &str) -> Option<String> {
        node.child_by_field_name(field)
            .map(|n| self.source[n.start_byte()..n.end_byte()].to_string())
    }

    fn node_range(&self, node: &tree_sitter::Node) -> Range {
        let start = node.start_position();
        let end = node.end_position();
        Range {
            start: Position { line: start.row as u32, character: start.column as u32 },
            end: Position { line: end.row as u32, character: end.column as u32 },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_function_symbols_collected() {
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = r#"int64 check(string x, bool y) {
    return 1;
}

int64 main() {
    int64 result = check("test", true);
    return result;
}
"#;
        let tree = parser.parse(source.as_bytes(), None).expect("parse failed");
        let root = tree.root_node();
        eprintln!("Root kind: '{}'", root.kind());

        // Dump all direct children of root
        eprintln!("Direct children of root:");
        let mut cursor = root.walk();
        for child in root.children(&mut cursor) {
            let name = child.child_by_field_name("name")
                .map(|n| source[n.start_byte()..n.end_byte()].to_string())
                .unwrap_or_default();
            eprintln!("  kind='{}' name='{}' range={}..{}",
                child.kind(), name,
                child.start_position().row, child.end_position().row);
        }

        let db = TypeDatabase::load();
        let model = SemanticModel::build(root, source, &db);
        eprintln!("\nCollected {} symbols:", model.symbols.len());
        for sym in &model.symbols {
            eprintln!("  {:?} '{}' range={}:{}..{}:{} type_name={:?} params={} ret={:?}",
                sym.kind, sym.name,
                sym.range.start.line, sym.range.start.character,
                sym.range.end.line, sym.range.end.character,
                sym.type_name,
                sym.params.len(),
                sym.return_type);
        }

        let check_sym = model.symbols.iter().find(|s| s.name == "check");
        assert!(check_sym.is_some(), "FAIL: 'check' function was NOT collected by semantic model!");
        let check = check_sym.unwrap();
        assert_eq!(check.kind, SymbolKind::Function, "FAIL: 'check' is not a Function");
        eprintln!("\nSUCCESS: 'check' function symbol found with {} params", check.params.len());

        let main_sym = model.symbols.iter().find(|s| s.name == "main");
        assert!(main_sym.is_some(), "FAIL: 'main' function was NOT collected!");
    }

    #[test]
    fn test_type_db_has_critical_types() {
        let db = TypeDatabase::load();
        // These MUST be findable via is_type
        for name in &["array", "window_info_t", "sidebar_section_t", "button_t", "menu_t",
                       "proc_t", "cpu_t", "http_response_t", "frame_t", "label_t"] {
            assert!(db.is_type(name), "FAIL: type '{}' not found via is_type()", name);
        }
        // These MUST be primitives
        for name in &["int64", "float64", "string", "bool", "void", "int32", "uint64"] {
            assert!(db.is_primitive(name), "FAIL: primitive '{}' not found", name);
        }
        // window_info_t should have methods
        let methods = db.get_methods("window_info_t");
        assert!(methods.is_some(), "FAIL: window_info_t has no methods");
        assert!(!methods.unwrap().is_empty(), "FAIL: window_info_t methods are empty");

        eprintln!("Type DB: {} types, {} functions, {} keywords",
            db.all_type_names.len(), db.functions.len(), db.keywords.len());
    }

    #[test]
    fn test_reference_site_resolution() {
        // Simulates the hover handler's reference-site lookup
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = r#"int64 add(int64 a, int64 b) {
    return a + b;
}

int64 main() {
    int64 result = add(3, 4);
    return result;
}
"#;
        let tree = parser.parse(source.as_bytes(), None).expect("parse failed");
        let root = tree.root_node();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(root, source, &db);

        // Find 'add' function
        let add_sym = model.symbols.iter().find(|s| s.name == "add").unwrap();
        let main_sym = model.symbols.iter().find(|s| s.name == "main").unwrap();

        // Simulate cursor at 'add' call site: line 5, the 'add' in 'add(3, 4)'
        // Line 5 in 0-indexed: row=5
        let call_pos = Position { line: 5, character: 21 }; // Position on 'add'

        // Declaration-site check: should NOT match (cursor is at call site, not in add's range)
        let decl_match = model.symbols.iter()
            .filter(|s| s.name == "add" && call_pos >= s.range.start && call_pos <= s.range.end)
            .min_by_key(|s| (s.range.end.line - s.range.start.line) * 1000);
        assert!(decl_match.is_none(), "FAIL: declaration-site check should NOT match at call site (but did)");

        // Reference-site check: should match 'add'
        let ref_match: Vec<_> = model.symbols.iter()
            .filter(|s| s.name == "add" && !(call_pos >= s.range.start && call_pos <= s.range.end))
            .collect();
        assert!(!ref_match.is_empty(), "FAIL: reference-site check found NO matches for 'add'");
        assert_eq!(ref_match[0].kind, SymbolKind::Function, "FAIL: reference match is not a Function");
        eprintln!("Reference-site check found 'add' correctly");

        // Verify 'add' symbol has expected data
        assert_eq!(add_sym.return_type, Some("int64".to_string()));
        assert_eq!(add_sym.params.len(), 2);
        eprintln!("'add' signature: params={} ret={:?}", add_sym.params.len(), add_sym.return_type);
    }

    #[test]
    fn test_full_hover_pipeline_e2e() {
        // End-to-end test that simulates the EXACT logic in the hover handler.
        // This proves that hovering over a reference site resolves to the definition.

        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }

        // This mimics a typical Enma file with a function definition and its call site
        let source = r#"int64 helper(string msg, int64 count) {
    println(msg);
    return count + 1;
}

int64 main() {
    int64 x = helper("hello", 42);
    //         ^ cursor here on 'helper'
    return x;
}
"#;
        let tree = parser.parse(source.as_bytes(), None).expect("parse failed");
        let root = tree.root_node();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(root, source, &db);

        // Helper function for leaf-finding (replicates find_named_leaf from main.rs)
        fn find_leaf(node: tree_sitter::Node, target: Position) -> Option<tree_sitter::Node> {
            let mut cursor = node.walk();
            for child in node.children(&mut cursor) {
                let cr = Range {
                    start: Position { line: child.start_position().row as u32, character: child.start_position().column as u32 },
                    end: Position { line: child.end_position().row as u32, character: child.end_position().column as u32 },
                };
                if target >= cr.start && target <= cr.end {
                    if child.child_count() == 0 || child.kind() == "identifier" {
                        return Some(child);
                    }
                    return find_leaf(child, target);
                }
            }
            None
        }

        fn in_range(r: &Range, p: Position) -> bool {
            p >= r.start && p <= r.end
        }

        // --- Test 1: hover at definition site (line 0, the 'helper' in 'int64 helper(...)') ---
        let def_pos = Position { line: 0, character: 6 }; // on 'helper' name
        let leaf = find_leaf(root, def_pos).expect("FAIL: no leaf at definition position");
        assert_eq!(leaf.kind(), "identifier", "FAIL: leaf is not identifier");

        // Declaration-site lookup
        let name = &source[leaf.start_byte()..leaf.end_byte()];
        assert_eq!(name, "helper");
        let def_result = model.symbols.iter()
            .filter(|s| s.name == name && in_range(&s.range, def_pos))
            .min_by_key(|s| (s.range.end.line - s.range.start.line) * 1000);
        assert!(def_result.is_some(), "FAIL: declaration-site lookup failed for 'helper' at definition");
        assert_eq!(def_result.unwrap().kind, SymbolKind::Function);
        eprintln!("TEST 1 PASS: declaration-site hover finds 'helper' at definition");

        // --- Test 2: hover at reference site (line 6, the 'helper' in 'helper("hello", 42)') ---
        let ref_line = 6u32;
        let ref_pos = Position { line: ref_line, character: 15 }; // on 'helper' in call
        let leaf2 = find_leaf(root, ref_pos).expect("FAIL: no leaf at reference position");
        assert_eq!(leaf2.kind(), "identifier");
        let name2 = &source[leaf2.start_byte()..leaf2.end_byte()];
        assert_eq!(name2, "helper");

        // Decl-site check should fail at reference site
        let decl_at_ref = model.symbols.iter()
            .filter(|s| s.name == name2 && in_range(&s.range, ref_pos))
            .min_by_key(|s| (s.range.end.line - s.range.start.line) * 1000);
        assert!(decl_at_ref.is_none(), "FAIL: decl-site check should NOT match at reference site");

        // Ref-site check should succeed
        let ref_result: Vec<_> = model.symbols.iter()
            .filter(|s| s.name == name2 && !in_range(&s.range, ref_pos))
            .collect();
        assert!(!ref_result.is_empty(), "FAIL: reference-site lookup found NO matches for 'helper'");
        let best = ref_result.iter().max_by_key(|s| match s.kind {
            SymbolKind::Function => 5, _ => 0,
        }).unwrap();
        assert_eq!(best.kind, SymbolKind::Function, "FAIL: best reference match is not a Function");
        assert_eq!(best.name, "helper");
        assert!(best.return_type.is_some(), "FAIL: 'helper' has no return type");
        eprintln!("TEST 2 PASS: reference-site hover correctly resolves 'helper' at call site (returns '{}')",
            best.return_type.as_deref().unwrap_or("?"));

        // --- Test 3: type database resolution for built-in and perception types ---
        // window_info_t
        assert!(db.is_type("window_info_t"), "FAIL: window_info_t not in DB");
        assert!(db.get_methods("window_info_t").unwrap().len() >= 6, "FAIL: window_info_t has too few methods");
        eprintln!("TEST 3 PASS: window_info_t has {} methods", db.get_methods("window_info_t").unwrap().len());

        // primitive int64
        assert!(db.is_primitive("int64"), "FAIL: int64 not a primitive");
        eprintln!("TEST 4 PASS: int64 is a primitive");

        // method lookup (hovering over 'length' should find string.length, array.length, etc.)
        let mut found_len = false;
        for (tname, methods) in &db.types {
            for m in methods {
                if m.name == "length" {
                    found_len = true;
                    eprintln!("TEST 5: method 'length' found on type '{}' -> {}", tname, m.r#return);
                }
            }
        }
        assert!(found_len, "FAIL: no types have 'length' method");
        eprintln!("TEST 5 PASS: method lookup works for 'length'");
    }
}
