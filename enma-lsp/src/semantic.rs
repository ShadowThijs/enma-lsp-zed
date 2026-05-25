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
            self.add_symbol(Self::empty_symbol(name, SymbolKind::Function, range));
        }
    }

    fn collect_struct(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        if let Some(name) = name {
            let range = self.node_range(&node);
            let mut sym = Self::empty_symbol(name, SymbolKind::Struct, range);
            self.extract_members(node, &mut sym);
            self.add_symbol(sym);
        }
    }

    fn collect_class(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        if let Some(name) = name {
            let range = self.node_range(&node);
            let mut sym = Self::empty_symbol(name, SymbolKind::Class, range);
            self.extract_members(node, &mut sym);
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
                        sym.methods.push(MethodInfo2 {
                            name: n, return_type: rtype, params: Vec::new(), range,
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
                _ => {}
            }
        }
    }

    fn collect_enum(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        if let Some(name) = name {
            let range = self.node_range(&node);
            self.add_symbol(Self::empty_symbol(name, SymbolKind::Enum, range));
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
        let name = self.child_text_by_field(node, "name");
        let type_name = self.child_text_by_field(node, "type");
        if let Some(name) = name {
            let range = self.node_range(&node);
            let mut sym = Self::empty_symbol(name, SymbolKind::Variable, range);
            sym.var_type = type_name;
            self.add_symbol(sym);
        }
    }

    fn collect_parameter(&mut self, node: tree_sitter::Node) {
        let name = self.child_text_by_field(node, "name");
        let type_name = self.child_text_by_field(node, "type");
        if let Some(name) = name {
            let range = self.node_range(&node);
            let mut sym = Self::empty_symbol(name, SymbolKind::Parameter, range);
            sym.var_type = type_name;
            self.add_symbol(sym);
        }
    }

    /// Check for type errors in the collected symbols.
    /// For now, reports basic issues; full type checking comes in later phases.
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
