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
    /// For methods/functions inside a struct/class: the owning type's name.
    pub owner_type: Option<String>,
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
    pub imports: Vec<String>,
}

impl SemanticModel {
    /// Build the semantic model from a tree-sitter tree + source text.
    pub fn build(root: tree_sitter::Node, source: &str, db: &TypeDatabase) -> Self {
        let mut collector = SymbolCollector::new(source);
        collector.walk(root);
        let diagnostics = collector.check_type_errors(db);
        Self {
            symbols: collector.symbols,
            diagnostics,
            imports: collector.imports,
        }
    }

    /// Merge symbols from an imported module into this model.
    /// Prefixes are not added - Enma uses `using` for namespace imports.
    pub fn merge_import(&mut self, other: SemanticModel, source_path: &str) {
        // Recurse into nested imports
        for import_path in &other.imports {
            // Track transitive imports - they get resolved by the caller
            if !self.imports.contains(import_path) {
                self.imports.push(import_path.clone());
            }
        }
        // Merge symbols, avoiding exact duplicates
        for sym in other.symbols {
            let is_dup = self.symbols.iter().any(|s| s.name == sym.name && s.kind == sym.kind);
            if !is_dup {
                self.symbols.push(sym);
            }
        }
        self.diagnostics.extend(other.diagnostics);
    }

    pub fn empty() -> Self {
        Self { symbols: Vec::new(), diagnostics: Vec::new(), imports: Vec::new() }
    }

    pub fn diagnostics(&self) -> Vec<Diagnostic> {
        self.diagnostics.clone()
    }
}

struct SymbolCollector<'a> {
    source: &'a str,
    symbols: Vec<Symbol>,
    imports: Vec<String>,
    /// Track variables in function scopes to detect re-declarations and type mismatches.
    scope_vars: Vec<HashMap<String, Symbol>>,
    /// When walking inside a struct/class body, this tracks the owning type name.
    current_owner: Option<String>,
}

impl<'a> SymbolCollector<'a> {
    fn new(source: &'a str) -> Self {
        Self {
            source,
            symbols: Vec::new(),
            imports: Vec::new(),
            scope_vars: vec![HashMap::new()],
            current_owner: None,
        }
    }

    /// Scan a block's children for ERROR(identifier) + expression_statement patterns
    /// which indicate unrecognized custom type declarations like `array test2;`
    fn scan_error_decls(&mut self, block: tree_sitter::Node) {
        // Collect child info as (kind, start_byte, end_byte, child_count) tuples
        let mut cursor = block.walk();
        let kids: Vec<(String, usize, usize, usize)> = block.children(&mut cursor).map(|c| {
            (c.kind().to_string(), c.start_byte(), c.end_byte(), c.child_count())
        }).collect();

        let mut i = 0;
        while i + 1 < kids.len() {
            let ckind = &kids[i].0;
            let cs = kids[i].1;
            let ce = kids[i].2;
            let ccount = kids[i].3;
            let nkind = &kids[i + 1].0;
            let ns = kids[i + 1].1;
            let ne = kids[i + 1].2;

            if ckind == "ERROR" && ccount > 0 {
                let err_text = &self.source[cs..ce];
                if let Some(type_name) = err_text.split_whitespace().next() {
                    let type_name = type_name.to_string();
                    let name_opt = if nkind == "expression_statement" {
                        let text = &self.source[ns..ne];
                        text.trim_end_matches(';').trim().split_whitespace().next().map(|s| s.to_string())
                    } else if nkind == "identifier" {
                        Some(self.source[ns..ne].to_string())
                    } else {
                        None
                    };
                    if let Some(name) = name_opt {
                        let range = self.range_from_bytes(cs, ce);
                        let mut sym = Self::empty_symbol(name, SymbolKind::Variable, range);
                        sym.var_type = Some(type_name.clone());
                        sym.type_name = Some(type_name);
                        self.add_symbol(sym);
                    }
                    i += 1;
                }
            }
            i += 1;
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
            owner_type: None,
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
            "import_statement" => {
                // import "path/file.em" or import "path/file" as alias
                if let Some(path_node) = node.child_by_field_name("path") {
                    let path = self.source[path_node.start_byte()..path_node.end_byte()].to_string();
                    // Strip quotes
                    let clean = path.trim_matches('"').to_string();
                    self.imports.push(clean);
                }
            }
            "function_definition" => self.collect_function(node),
            "function_declaration" => self.collect_function(node),
            "method_declaration" => self.collect_function(node),
            "struct_declaration" => {
                let saved = self.current_owner.clone();
                self.current_owner = self.child_text_by_field(node, "name");
                self.collect_struct(node);
                self.walk_children(node);
                self.current_owner = saved;
                return;
            }
            "class_declaration" => {
                let saved = self.current_owner.clone();
                self.current_owner = self.child_text_by_field(node, "name");
                self.collect_class(node);
                self.walk_children(node);
                self.current_owner = saved;
                return;
            }
            "enum_declaration" => self.collect_enum(node),
            "interface_declaration" => self.collect_interface(node),
            "namespace_definition" => self.collect_namespace(node),
            "global_variable_declaration" => self.collect_variable(node),
            "declaration_statement" => self.collect_variable(node),
            // expression_statement can contain variable-like declarations when the
            // grammar doesn't recognize a custom type name.
            "expression_statement" => {
                // Collect info for children: (kind, start_byte, end_byte, child_count)
                let mut cursor = node.walk();
                let child_info: Vec<_> = node.children(&mut cursor).map(|c| {
                    (c.kind().to_string(), c.start_byte(), c.end_byte(), c.child_count())
                }).collect();
                if child_info.len() >= 2 && child_info[0].0 == "identifier" {
                    let type_name = self.source[child_info[0].1..child_info[0].2].to_string();
                    // Find the variable name - may be after `<...>` for generic types
                    let name_opt = if child_info[1].0 == "identifier" {
                        Some(self.source[child_info[1].1..child_info[1].2].to_string())
                    } else if child_info[1].0 == "<" {
                        // Generic type: `array < string > varname`
                        // Skip past matching angle brackets to find the variable name
                        let mut depth = 1;
                        let mut idx = 2;
                        while idx < child_info.len() && depth > 0 {
                            if child_info[idx].0 == "<" { depth += 1; }
                            else if child_info[idx].0 == ">" { depth -= 1; }
                            idx += 1;
                        }
                        if idx < child_info.len() && child_info[idx].0 == "identifier" {
                            Some(self.source[child_info[idx].1..child_info[idx].2].to_string())
                        } else {
                            None
                        }
                    } else if child_info[1].0 == "ERROR" && child_info[1].3 > 0 {
                        let err_text = &self.source[child_info[1].1..child_info[1].2];
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
                // Scan for ERROR(identifier) + expression_statement(identifier) patterns
                // which represent unrecognized type declarations like `array test2;`
                self.scan_error_decls(node);
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
            // GLR parser may produce function_definition nodes for call/assignment
            // expressions. Real definitions have a `{` body block in their source text.
            let node_text = &self.source[node.start_byte()..node.end_byte()];
            let has_body_brace = node_text.contains('{');
            let is_decl = matches!(node.kind(), "function_declaration" | "method_declaration");
            if !has_body_brace && !is_decl {
                return;
            }
            let range = self.node_range(&node);
            let return_type = self.child_text_by_field(node, "return_type");
            let params = self.extract_params(node);
            let mut sym = Self::empty_symbol(name.clone(), SymbolKind::Function, range);
            sym.return_type = return_type;
            sym.params = params;
            sym.owner_type = self.current_owner.clone();
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
                    // The 'name' field returns just the class name; prepend '~' to distinguish
                    if let Some(dtor_name) = self.child_text_by_field(child, "name") {
                        let range = self.node_range(&child);
                        sym.methods.push(MethodInfo2 {
                            name: format!("~{}", dtor_name), return_type: None, params: Vec::new(), range,
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
    /// Performs: duplicate detection, generic type validation, basic type mismatch checks,
    /// and method call validation.
    fn check_type_errors(&self, db: &TypeDatabase) -> Vec<Diagnostic> {
        let mut diags = self.check_duplicates();
        diags.extend(self.check_generic_params());
        diags.extend(self.check_type_mismatches(db));
        diags.extend(self.check_method_calls(db));
        diags
    }

    fn check_duplicates(&self) -> Vec<Diagnostic> {
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

        // Also check for duplicate top-level definitions (struct/class/enum).
        // Functions are NOT checked here - function overloading is valid in Enma,
        // and the scope-based check above already catches exact duplicates.
        let def_kinds = [SymbolKind::Struct, SymbolKind::Class,
                         SymbolKind::Enum, SymbolKind::Interface, SymbolKind::Namespace];
        for i in 0..self.symbols.len() {
            let sym = &self.symbols[i];
            if !def_kinds.contains(&sym.kind) { continue; }
            for j in (i+1)..self.symbols.len() {
                let other = &self.symbols[j];
                if !def_kinds.contains(&other.kind) { continue; }
                if sym.name == other.name && sym.kind == other.kind {
                    // Methods in different classes/structs are NOT duplicates
                    if sym.kind == SymbolKind::Function
                        && sym.owner_type.is_some()
                        && other.owner_type.is_some()
                        && sym.owner_type != other.owner_type
                    {
                        continue;
                    }
                    // Skip GLR artifacts: function_definition nodes produced from call sites
                    // have no return_type (the GLR misinterprets `S("text")` as a definition)
                    if sym.kind == SymbolKind::Function
                        && (sym.return_type.is_none() || other.return_type.is_none())
                    {
                        continue;
                    }
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

    /// Check for generic types used without required parameters.
    /// e.g., `array test2;` should error because array requires <T>.
    fn check_generic_params(&self) -> Vec<Diagnostic> {
        let mut diags = Vec::new();
        let generic_types = ["list", "hash_set", "sorted_map", "imap"];
        for sym in &self.symbols {
            if sym.kind == SymbolKind::Variable || sym.kind == SymbolKind::Parameter {
                if let Some(ref vt) = sym.var_type {
                    let base = vt.trim_end_matches("[]");
                    if generic_types.contains(&base) && !vt.contains('<') {
                        diags.push(Diagnostic {
                            range: sym.range,
                            severity: Some(DiagnosticSeverity::ERROR),
                            code: Some(NumberOrString::String("missing-generic-params".into())),
                            source: Some("enma-lsp".into()),
                            message: format!("Type '{}' requires generic parameters, e.g. '{}<T>'", base, base),
                            ..Default::default()
                        });
                    }
                }
            }
        }
        diags
    }

    /// Detect type mismatches: declared variable type vs known function return type.
    /// Checks both built-in functions (type DB) and user-defined functions (semantic model).
    fn check_type_mismatches(&self, db: &TypeDatabase) -> Vec<Diagnostic> {
        let mut diags = Vec::new();
        for sym in &self.symbols {
            if sym.kind != SymbolKind::Variable { continue; }
            let Some(ref vt) = sym.var_type else { continue };
            // Extract the RHS of the declaration from source text
            let range = &sym.range;
            let start_byte = self.pos_to_byte(range.start);
            let end_byte = self.pos_to_byte(range.end).min(self.source.len());
            if start_byte >= self.source.len() { continue; }
            let decl_text = &self.source[start_byte..end_byte];
            let Some(eq_pos) = decl_text.find('=') else { continue };
            let rhs = decl_text[eq_pos + 1..].trim();
            let Some(open_paren) = rhs.find('(') else { continue };
            let fn_name = rhs[..open_paren].trim().trim_end_matches(';').trim_end_matches(')');
            // First check built-in functions
            let ret_type: Option<&str> = if let Some(func) = db.functions.get(fn_name) {
                Some(func.r#return.as_str())
            } else {
                // Check user-defined functions in the semantic model
                self.symbols.iter()
                    .find(|s| s.kind == SymbolKind::Function && s.name == fn_name)
                    .and_then(|f| f.return_type.as_deref())
            };
            let Some(ret_type) = ret_type else { continue };
            // Skip user-defined functions with bogus return types (GLR artifacts
            // that parse assignments as function definitions - return type is a
            // variable name, not a real type).
            if !db.functions.contains_key(fn_name) && !is_valid_type_name(ret_type, db, self) {
                continue;
            }
            // Skip type mismatch for overloaded math functions that work with both int64 and float64
            if matches!(fn_name, "abs" | "min" | "max" | "clamp")
                && ((vt == "int64" && ret_type == "float64") || (vt == "float64" && ret_type == "int64"))
            {
                continue;
            }
            // coroutine_t is a handle type - any int assignment is valid
            if vt == "coroutine_t" { continue; }
            // void return assigned to non-void variable is a mismatch
            if ret_type == "void" {
                if vt != "void" {
                    diags.push(Diagnostic {
                        range: sym.range,
                        severity: Some(DiagnosticSeverity::ERROR),
                        code: Some(NumberOrString::String("type-mismatch".into())),
                        source: Some("enma-lsp".into()),
                        message: format!(
                            "Type mismatch: '{}' declared as '{}' but '{}()' returns 'void'",
                            sym.name, vt, fn_name
                        ),
                        ..Default::default()
                    });
                }
                continue;
            }
            // Normalize both types
            let norm_decl = strip_generic(vt);
            let norm_ret = strip_generic(ret_type);
            // auto is type inference; any compatible RHS type is valid.
            if norm_decl == "auto" { continue; }
            if norm_decl != norm_ret {
                // Skip if there's an explicit cast
                if rhs.contains(&format!("cast<{}>", vt)) { continue; }
                diags.push(Diagnostic {
                    range: sym.range,
                    severity: Some(DiagnosticSeverity::ERROR),
                    code: Some(NumberOrString::String("type-mismatch".into())),
                    source: Some("enma-lsp".into()),
                    message: format!(
                        "Type mismatch: '{}' declared as '{}' but '{}()' returns '{}'",
                        sym.name, vt, fn_name, ret_type
                    ),
                    ..Default::default()
                });
            }
        }
        diags
    }

    /// Find a variable's declared type by name, preferring the declaration
    /// closest to `at_byte` (to handle shadowing across functions/scopes).
    fn resolve_var_type(&self, var_name: &str, at_byte: usize) -> Option<String> {
        self.symbols.iter()
            .filter(|s| s.name == var_name)
            .filter(|s| matches!(s.kind, SymbolKind::Variable | SymbolKind::Parameter))
            .filter(|s| self.pos_to_byte(s.range.start) <= at_byte)
            .max_by_key(|s| self.pos_to_byte(s.range.start))
            .and_then(|s| s.var_type.clone())
    }

    /// Check whether a method exists on a given type (built-in or custom).
    fn method_exists_on_type(&self, db: &TypeDatabase, method_name: &str, type_name: &str) -> bool {
        let normalized = strip_generic(type_name);
        // Check math types (fields + methods) - must check before db.get_methods()
        // because get_methods merges math_type methods but NOT math_type fields.
        if let Some(mt) = db.math_types.get(normalized) {
            if mt.methods.iter().any(|m| m.name == method_name) {
                return true;
            }
            if mt.fields.iter().any(|f| f == method_name) {
                return true;
            }
            return false;
        }
        if let Some(methods) = db.get_methods(normalized) {
            return methods.iter().any(|m| m.name == method_name);
        }
        for sym in &self.symbols {
            if sym.name == normalized && (sym.kind == SymbolKind::Struct || sym.kind == SymbolKind::Class) {
                if sym.methods.iter().any(|m| m.name == method_name) {
                    return true;
                }
                if sym.fields.iter().any(|f| f.name == method_name) {
                    return true;
                }
                return false;
            }
        }
        if db.is_primitive(normalized) {
            return false;
        }
        true
    }

    /// Check whether a position in source is inside a string literal.
    fn is_inside_string(&self, byte_pos: usize) -> bool {
        let before = &self.source[..byte_pos];
        let mut quote_count = 0usize;
        let mut chars = before.chars();
        while let Some(ch) = chars.next() {
            if ch == '\\' {
                chars.next(); // skip escaped character
            } else if ch == '"' {
                quote_count += 1;
            }
        }
        quote_count % 2 != 0
    }

    /// Scan source for `.methodName(` patterns and check if the method exists on the
    /// receiver's declared type. Emits errors for method calls on incompatible types.
    fn check_method_calls(&self, db: &TypeDatabase) -> Vec<Diagnostic> {
        let mut diags = Vec::new();
        let source = self.source;
        let mut search_start = 0;

        while let Some(dot_pos) = source[search_start..].find('.') {
            let abs_dot = search_start + dot_pos;
            search_start = abs_dot + 1;

            // Skip dots inside string literals - they're data, not code
            if self.is_inside_string(abs_dot) {
                continue;
            }

            // Extract the identifier immediately after the dot
            let after_dot = &source[abs_dot + 1..];
            let method_name: String = after_dot.chars()
                .take_while(|c| c.is_alphanumeric() || *c == '_')
                .collect();
            if method_name.is_empty() {
                continue;
            }

            // Must be followed by '(' (with optional whitespace)
            let after_method = &after_dot[method_name.len()..];
            if !after_method.trim_start().starts_with('(') {
                continue;
            }

            // Extract receiver name before the dot
            let before_dot = &source[..abs_dot];
            // Handle subscript: cs[0].inc() → strip the subscript part
            let before_clean = if let Some(bracket) = before_dot.rfind('[') {
                let between = &before_dot[bracket + 1..];
                if !between.contains('.') {
                    before_dot[..bracket].to_string()
                } else {
                    before_dot.to_string()
                }
            } else {
                before_dot.to_string()
            };

            let receiver = before_clean.trim_end()
                .rsplit(|c: char| !c.is_alphanumeric() && c != '_')
                .next()
                .unwrap_or("")
                .to_string();

            // Skip numeric receivers (e.g. 0.5, 1.0)
            if receiver.is_empty() || receiver.chars().all(|c| c.is_numeric()) {
                continue;
            }

            // Look up receiver type
            if let Some(receiver_type) = self.resolve_var_type(&receiver, abs_dot) {
                let normalized = strip_generic(&receiver_type);
                let type_is_known = db.is_primitive(normalized)
                    || db.is_type(normalized)
                    || db.math_types.contains_key(normalized)
                    || self.symbols.iter().any(|s|
                        s.name == normalized
                        && (s.kind == SymbolKind::Struct || s.kind == SymbolKind::Class));

                // auto is type inference; skip method existence checks since we
                // don't know the concrete type at compile time.
                if normalized == "auto" { continue; }

                if type_is_known && !self.method_exists_on_type(db, &method_name, &receiver_type) {
                    let (line, col) = self.byte_to_line_col(abs_dot);
                    diags.push(Diagnostic {
                        range: Range {
                            start: Position { line, character: col },
                            end: Position { line, character: col + method_name.len() as u32 + 1 },
                        },
                        severity: Some(DiagnosticSeverity::ERROR),
                        code: Some(NumberOrString::String("method-not-found".into())),
                        source: Some("enma-lsp".into()),
                        message: format!(
                            "Method '{}()' not found on type '{}'",
                            method_name, normalized
                        ),
                        ..Default::default()
                    });
                }
            }
        }
        diags
    }
}

/// Check if a string looks like a valid Enma type name (not a GLR artifact variable name).
fn is_valid_type_name(name: &str, db: &TypeDatabase, collector: &SymbolCollector) -> bool {
    // Known types and primitives
    if db.is_type(name) || db.is_primitive(name) || db.math_types.contains_key(name) {
        return true;
    }
    // Known struct/class/enum in the model
    if collector.symbols.iter().any(|s| {
        s.name == name && matches!(s.kind, SymbolKind::Struct | SymbolKind::Class | SymbolKind::Enum)
    }) {
        return true;
    }
    // Perception SDK types (end with _t)
    if name.ends_with("_t") { return true; }
    // Generic types
    let base = strip_generic(name);
    if db.is_type(base) || db.is_primitive(base) || db.math_types.contains_key(base) {
        return true;
    }
    // Common type names and builtins
    matches!(name, "void" | "int8" | "int16" | "int32" | "int64" | "uint8" | "uint16" | "uint32" | "uint64" | "float32" | "float64" | "bool" | "string" | "wstring" | "auto" | "coroutine_t")
}

impl<'a> SymbolCollector<'a> {
    fn byte_to_line_col(&self, byte: usize) -> (u32, u32) {
        let mut line = 0u32;
        let mut col = 0u32;
        let mut pos = 0usize;
        for ch in self.source.chars() {
            if pos >= byte { break; }
            if ch == '\n' { line += 1; col = 0; }
            else { col += 1; }
            pos += ch.len_utf8();
        }
        (line, col)
    }

    fn pos_to_byte(&self, pos: Position) -> usize {
        let mut offset = 0usize;
        for (i, line) in self.source.lines().enumerate() {
            if (i as u32) < pos.line { offset += line.len() + 1; }
            else { break; }
        }
        (offset + pos.character as usize).min(self.source.len())
    }

    fn range_from_bytes(&self, start_byte: usize, end_byte: usize) -> Range {
        let mut line = 0u32;
        let mut col = 0u32;
        let mut pos = 0usize;
        for ch in self.source.chars() {
            if pos >= start_byte { break; }
            if ch == '\n' { line += 1; col = 0; }
            else { col += 1; }
            pos += ch.len_utf8();
        }
        let start = Position { line, character: col };
        // Approximate end position (not perfectly accurate for multi-line ranges)
        let end = Position { line, character: col + (end_byte - start_byte) as u32 };
        Range { start, end }
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

/// Strip generic parameters, array brackets, pointers, and references from a type name.
/// "int64[]" → "array" (T[] is syntactic sugar for array<T>)
/// "Cell*" → "Cell", "int64&" → "int64"
fn strip_generic(type_name: &str) -> &str {
    let s = type_name.trim_end_matches('*').trim_end_matches('&');
    if s.ends_with("[]") {
        return "array";
    }
    if let Some(pos) = s.find('<') { &s[..pos] } else { s }
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
    fn test_generic_param_errors() {
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = "int64 main() {\n    list test2;\n    return 0;\n}\n";
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(tree.root_node(), source, &db);

        eprintln!("Symbols:");
        for sym in &model.symbols {
            eprintln!("  {:?} '{}' var_type={:?}", sym.kind, sym.name, sym.var_type);
        }
        eprintln!("Diagnostics:");
        for d in &model.diagnostics {
            eprintln!("  {}: {}", d.code.as_ref().map(|c| match c { NumberOrString::String(s) => s.as_str(), _ => "?" }).unwrap_or("?"), d.message);
        }

        // Should detect 'list test2;' as missing generic params
        let has_generic_err = model.diagnostics.iter().any(|d| {
            d.message.contains("requires generic parameters") && d.message.contains("list")
        });
        assert!(has_generic_err, "FAIL: no 'requires generic parameters' error for 'list test2;'. Diagnostics: {:?}",
            model.diagnostics.iter().map(|d| &d.message).collect::<Vec<_>>());
        eprintln!("PASS: generic param error detected");
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

    #[test]
    fn test_cross_class_method_no_duplicate_error() {
        // Methods with the same name in DIFFERENT classes should NOT be flagged as duplicates
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = r#"class T24_A {
    int64 av;
    T24_A() { av = 1; }
    int64 sig() { return 10; }
}
class T24_B {
    int64 bv;
    T24_B() { bv = 2; }
    int64 sig() { return 20; }
    int64 take(int64 v) { return v + bv; }
}
class T24_C {
    T24_C() { }
    int64 sig() { return 999; }
    int64 take(int64 v) { return v + 1000; }
}
"#;
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(tree.root_node(), source, &db);

        eprintln!("Symbols ({}):", model.symbols.len());
        for sym in &model.symbols {
            eprintln!("  {:?} '{}' owner={:?}", sym.kind, sym.name, sym.owner_type);
        }
        eprintln!("Diagnostics:");
        for d in &model.diagnostics {
            eprintln!("  {}: {}", d.code.as_ref().map(|c| match c { NumberOrString::String(s) => s.as_str(), _ => "?" }).unwrap_or("?"), d.message);
        }

        // Should NOT have duplicate errors for sig() across T24_A, T24_B, T24_C
        let dup_errors: Vec<_> = model.diagnostics.iter()
            .filter(|d| d.message.contains("Duplicate") && d.message.contains("sig"))
            .collect();
        assert!(dup_errors.is_empty(),
            "FAIL: sig() in different classes should not be duplicates. Got: {:?}",
            dup_errors.iter().map(|d| &d.message).collect::<Vec<_>>());

        // Should NOT have duplicate errors for take() across T24_B, T24_C
        let take_errors: Vec<_> = model.diagnostics.iter()
            .filter(|d| d.message.contains("Duplicate") && d.message.contains("take"))
            .collect();
        assert!(take_errors.is_empty(),
            "FAIL: take() in different classes should not be duplicates. Got: {:?}",
            take_errors.iter().map(|d| &d.message).collect::<Vec<_>>());

        eprintln!("PASS: cross-class methods with same name are not flagged as duplicates");
    }

    #[test]
    fn test_custom_function_return_type_mismatch() {
        // User-defined function returning one type assigned to different-typed variable
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = r#"array<window_info_t> test_random() {
    return (0);
}

int64 main() {
    string test = test_random();
    return 0;
}
"#;
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(tree.root_node(), source, &db);

        eprintln!("Symbols:");
        for sym in &model.symbols {
            eprintln!("  {:?} '{}' ret={:?} var_type={:?}", sym.kind, sym.name, sym.return_type, sym.var_type);
        }
        eprintln!("Diagnostics:");
        for d in &model.diagnostics {
            eprintln!("  {}: {}", d.code.as_ref().map(|c| match c { NumberOrString::String(s) => s.as_str(), _ => "?" }).unwrap_or("?"), d.message);
        }

        // Should detect: string test = test_random(); → test_random() returns array<window_info_t>, not string
        let mismatch = model.diagnostics.iter().any(|d| {
            d.message.contains("Type mismatch")
            && d.message.contains("test_random")
            && d.message.contains("string")
            && d.message.contains("array")
        });
        assert!(mismatch,
            "FAIL: should detect type mismatch for 'string test = test_random()' where test_random returns array<window_info_t>. Diagnostics: {:?}",
            model.diagnostics.iter().map(|d| &d.message).collect::<Vec<_>>());
        eprintln!("PASS: custom function return type mismatch detected");
    }

    #[test]
    fn test_method_not_found_on_primitive() {
        // int64 value; value.length(); → error: length() not on int64
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = r#"int64 main() {
    int64 value = 42;
    int64 n = value.length();
    return n;
}
"#;
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(tree.root_node(), source, &db);

        eprintln!("Diagnostics:");
        for d in &model.diagnostics {
            eprintln!("  {}: {}", d.code.as_ref().map(|c| match c { NumberOrString::String(s) => s.as_str(), _ => "?" }).unwrap_or("?"), d.message);
        }

        let has_error = model.diagnostics.iter().any(|d| {
            d.message.contains("not found on type") && d.message.contains("length") && d.message.contains("int64")
        });
        assert!(has_error,
            "FAIL: should error that length() is not found on int64. Diagnostics: {:?}",
            model.diagnostics.iter().map(|d| &d.message).collect::<Vec<_>>());
        eprintln!("PASS: method-not-found error for int64.length()");
    }

    #[test]
    fn test_delete_tokenization() {
        // Verify how delete and delete[] are tokenized by the parser
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = "int64 main() { int64* p = new int64; delete p; delete[] p; return 0; }";
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let root = tree.root_node();

        fn find_tokens(node: tree_sitter::Node, source: &str, depth: usize) {
            if node.child_count() == 0 {
                let text = &source[node.start_byte()..node.end_byte()];
                if text.contains("delete") || text == "[" || text == "]" {
                    eprintln!("  {:indent$}kind='{}' text='{}'", "", node.kind(), text, indent=depth*2);
                }
            }
            let mut cursor = node.walk();
            for child in node.children(&mut cursor) {
                find_tokens(child, source, depth + 1);
            }
        }
        eprintln!("Token tree for delete/delete[] test:");
        find_tokens(root, source, 0);

        // Check that the source contains delete and delete[]
        assert!(source.contains("delete p"), "source should contain 'delete p'");
        assert!(source.contains("delete[] p"), "source should contain 'delete[] p'");
        eprintln!("PASS: delete[] tokenization dump complete");
    }

    #[test]
    fn test_string_literal_method_scan_skipped() {
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = r#"int64 main() {
    map<int64, string> m;
    array<string> ks = m.keys();
    array<int64>  vs = m.values();
    check("keys().length() == size()", ks.length() == m.size());
    check("values().length() == size()", vs.length() == m.size());
    return 0;
}
"#;
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(tree.root_node(), source, &db);

        eprintln!("Diagnostics:");
        for d in &model.diagnostics {
            eprintln!("  {}: {}", d.code.as_ref().map(|c| match c { NumberOrString::String(s) => s.as_str(), _ => "?" }).unwrap_or("?"), d.message);
        }

        let method_errors: Vec<_> = model.diagnostics.iter()
            .filter(|d| d.message.contains("not found on type"))
            .collect();
        assert!(method_errors.is_empty(),
            "FAIL: false method-not-found errors from string literals. Got: {:?}",
            method_errors.iter().map(|d| &d.message).collect::<Vec<_>>());
        eprintln!("PASS: method calls inside string literals are correctly skipped");
    }

    #[test]
    fn test_cpu_methods_not_flagged() {
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = r#"int64 main() {
    cpu_t cpu = cpu_create();
    int64 result = cpu.start(0x1000, 0x1100, 0, 2);
    check("cpu.start(...) returns 0 (UC_ERR_OK)", result == 0);
    int64 rax = cpu.reg_read64(uc_reg::rax);
    return rax;
}
"#;
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(tree.root_node(), source, &db);

        eprintln!("Symbols:");
        for sym in &model.symbols {
            eprintln!("  {:?} '{}' var_type={:?}", sym.kind, sym.name, sym.var_type);
        }
        eprintln!("Diagnostics:");
        for d in &model.diagnostics {
            eprintln!("  {}: {}", d.code.as_ref().map(|c| match c { NumberOrString::String(s) => s.as_str(), _ => "?" }).unwrap_or("?"), d.message);
        }

        let false_errors: Vec<_> = model.diagnostics.iter()
            .filter(|d| d.message.contains("not found on type"))
            .filter(|d| d.message.contains("start") || d.message.contains("reg_read64"))
            .collect();
        assert!(false_errors.is_empty(),
            "FAIL: cpu_t methods incorrectly flagged. Got: {:?}",
            false_errors.iter().map(|d| &d.message).collect::<Vec<_>>());
        eprintln!("PASS: cpu_t methods not flagged as errors");
    }

    #[test]
    fn test_generic_expression_statement_parse() {
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = "int64 main() { array<string> ks = m.keys(); return 0; }";
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let root = tree.root_node();

        fn dump_kids(node: tree_sitter::Node, source: &str, depth: usize) {
            let mut cursor = node.walk();
            for child in node.children(&mut cursor) {
                let text = &source[child.start_byte()..child.end_byte()];
                let short = if text.len() > 50 { &text[..50] } else { text };
                eprintln!("{:indent$}{} [{}] '{}'", "", child.kind(), child.child_count(), short.replace('\n', "\\n"), indent=depth*2);
                if child.child_count() > 0 {
                    dump_kids(child, source, depth + 1);
                }
            }
        }
        eprintln!("Parse tree for 'array<string> ks = m.keys();':");
        dump_kids(root, source, 0);

        let db = TypeDatabase::load();
        let model = SemanticModel::build(tree.root_node(), source, &db);
        eprintln!("\nCollected symbols:");
        for sym in &model.symbols {
            eprintln!("  {:?} '{}' var_type={:?}", sym.kind, sym.name, sym.var_type);
        }

        let ks = model.symbols.iter().find(|s| s.name == "ks");
        if let Some(ks) = ks {
            eprintln!("ks collected: var_type={:?}", ks.var_type);
        } else {
            eprintln!("ks NOT collected - generic type parse issue");
        }
    }

    #[test]
    fn test_uint8_array_variable_collected() {
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = "int32 main() { uint8[] rgba_tex; rgba_tex.push(255); return 0; }";
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let db = TypeDatabase::load();
        let model = SemanticModel::build(tree.root_node(), source, &db);
        eprintln!("Symbols:");
        for sym in &model.symbols {
            eprintln!("  {:?} '{}' var_type={:?}", sym.kind, sym.name, sym.var_type);
        }
        let rgba = model.symbols.iter().find(|s| s.name == "rgba_tex");
        assert!(rgba.is_some(), "FAIL: rgba_tex not collected. Symbols: {:?}",
            model.symbols.iter().map(|s| format!("{}:{:?}", s.name, s.kind)).collect::<Vec<_>>());
        if let Some(rgba) = rgba {
            eprintln!("rgba_tex var_type={:?}", rgba.var_type);
        }
    }

    #[test]
    fn test_render_api_parse_errors() {
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
            let lang = tree_sitter::Language::from_raw(lang_fn() as *const _);
            parser.set_language(&lang).unwrap();
        }
        let source = r#"int32 main() {
    uint8[] rgba_tex;
    rgba_tex.push(255);
    rgba_tex.push(128);
    return 0;
}
"#;
        let tree = parser.parse(source.as_bytes(), None).unwrap();
        let root = tree.root_node();
        fn dump_errors(node: tree_sitter::Node, source: &str) {
            if node.is_error() && node.child_count() == 0 {
                let text = &source[node.start_byte()..node.end_byte()];
                eprintln!("  ERROR leaf L{}:C{} '{}' (kind={})",
                    node.start_position().row, node.start_position().column,
                    text, node.kind());
            }
            let mut cursor = node.walk();
            for child in node.children(&mut cursor) {
                dump_errors(child, source);
            }
        }
        eprintln!("ERROR leaves in minimal render_api reproduction:");
        dump_errors(root, source);

        // Test: does create_constant_buffer(64) parse?
        let source2 = "int32 main() { int64 x = create_constant_buffer(64); return 0; }";
        let tree2 = parser.parse(source2.as_bytes(), None).unwrap();
        let root2 = tree2.root_node();
        eprintln!("\nERROR leaves for create_constant_buffer(64):");
        dump_errors(root2, source2);

        // Test: does integer argument to a method call parse?
        let source3 = "int32 main() { int64 cb; cb = create_constant_buffer(64); return 0; }";
        let tree3 = parser.parse(source3.as_bytes(), None).unwrap();
        let root3 = tree3.root_node();
        eprintln!("\nERROR leaves for cb = create_constant_buffer(64):");
        dump_errors(root3, source3);

        // Also test with full render_api.em
        let full_path = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../test/perception Api/render_api.em");
        if full_path.exists() {
            let full_source = std::fs::read_to_string(&full_path).unwrap();
            let full_tree = parser.parse(full_source.as_bytes(), None).unwrap();
            let full_root = full_tree.root_node();
            eprintln!("\nERROR leaves in FULL render_api.em (first 30):");
            let mut count = 0;
            fn dump_errors2(node: tree_sitter::Node, source: &str, count: &mut i32) {
                if node.is_error() && node.child_count() == 0 {
                    if *count < 30 {
                        let text = &source[node.start_byte()..node.end_byte()];
                        eprintln!("  ERROR L{}:C{} '{}'",
                            node.start_position().row, node.start_position().column,
                            text.replace('\n', "\\n"));
                    }
                    *count += 1;
                }
                let mut cursor = node.walk();
                for child in node.children(&mut cursor) {
                    dump_errors2(child, source, count);
                }
            }
            dump_errors2(full_root, &full_source, &mut count);
            eprintln!("  ... {} total ERROR leaves", count);

            // Check if parse covers the full file
            let total_bytes = full_source.len();
            let covered = full_root.end_byte();
            eprintln!("\nParse coverage: {}/{} bytes ({}%)",
                covered, total_bytes,
                if total_bytes > 0 { covered * 100 / total_bytes } else { 0 });

            // === DIAGNOSTIC: scan ALL check() calls ===
            eprintln!("\n=== ALL check() call parent types ===");
            fn all_check_parents(node: tree_sitter::Node, source: &str,
                                  results: &mut Vec<(usize, String, String)>) {
                if node.kind() == "identifier" {
                    let text = &source[node.start_byte()..node.end_byte()];
                    if text == "check" {
                        let pkind = node.parent()
                            .map(|p| p.kind().to_string())
                            .unwrap_or_default();
                        let gpk = node.parent().and_then(|p| p.parent())
                            .map(|p| p.kind().to_string())
                            .unwrap_or_default();
                        let ptxt: String = node.parent()
                            .map(|p| &source[p.start_byte()..p.end_byte()])
                            .unwrap_or("").to_string();
                        results.push((node.start_position().row, pkind,
                            format!("gp={} |{}", gpk,
                                ptxt.chars().take(55).collect::<String>().replace('\n', " "))));
                    }
                }
                let mut cursor = node.walk();
                for child in node.children(&mut cursor) {
                    all_check_parents(child, source, results);
                }
            }
            let mut all = Vec::new();
            all_check_parents(full_root, &full_source, &mut all);
            let mut prev = String::new();
            for (row, pkind, detail) in &all {
                if *pkind != prev {
                    eprintln!("  --- parent={} at L{} ---", pkind, row);
                    prev = pkind.clone();
                }
                eprintln!("    L{}: parent={} {}", row, pkind, detail);
            }
            eprintln!("  Total: {} check() call sites", all.len());

            // === DIAGNOSTIC: function spans ===
            eprintln!("\n=== function_definition spans ===");
            fn func_spans(node: tree_sitter::Node, source: &str) {
                if node.kind() == "function_definition" {
                    if let Some(name) = node.child_by_field_name("name") {
                        let n = &source[name.start_byte()..name.end_byte()];
                        let bi = node.child_by_field_name("body")
                            .map(|b| format!("body L{}-L{}", b.start_position().row, b.end_position().row))
                            .unwrap_or_else(|| "NO BODY".to_string());
                        eprintln!("  fn '{}' L{}-L{} {}", n, node.start_position().row, node.end_position().row, bi);
                    }
                }
                let mut cursor = node.walk();
                for child in node.children(&mut cursor) {
                    func_spans(child, source);
                }
            }
            func_spans(full_root, &full_source);

            // Test em dash in string
            let em_source = "int32 main() { string s = \"hello - world\"; return 0; }";
            let em_tree = parser.parse(em_source.as_bytes(), None).unwrap();
            let em_root = em_tree.root_node();
            eprintln!("\nERROR leaves for em dash string:");
            dump_errors(em_root, em_source);
        }
    }
}
