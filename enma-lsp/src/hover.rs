//! Hover resolution: detect context, format hover content, resolve types.
//! Shared between the LSP server and the CLI test tool.

use crate::type_db::TypeDatabase;
use crate::semantic::{self, SemanticModel, SymbolKind};
use tower_lsp::lsp_types::{Position, Range};

pub fn format_local_symbol_hover(sym: &semantic::Symbol) -> String {
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
                let (dtors, regular): (Vec<_>, Vec<_>) = sym.methods.iter()
                    .partition(|m| m.name.starts_with('~'));
                md.push_str(" {\n");
                for f in &sym.fields {
                    if let Some(ref ft) = f.field_type {
                        md.push_str(&format!("    {}: {};\n", f.name, ft));
                    } else {
                        md.push_str(&format!("    {};\n", f.name));
                    }
                }
                if !sym.fields.is_empty() && !regular.is_empty() {
                    md.push('\n');
                }
                for m in &regular {
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
                for d in &dtors {
                    md.push_str(&format!("    {}(); // cleanup\n", d.name));
                }
                md.push_str("}\n");
            }
            md.push_str("```\n");
            md.push_str(&format!("**{}** `{}`", kind_str, sym.name));
            let fc = sym.fields.len();
            let mc = sym.methods.len();
            md.push_str(&format!(" - {} field{}, {} method{}",
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
                        md.push_str(&format!("- `~{}()` - destructor, runs when `delete` is called\n", clean_name));
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
                md.push_str(&format!(" - {} variant{}", vc, if vc == 1 { "" } else { "s" }));
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

/// Format hover for a FIELD access on a custom struct/class or math type (e.g. cs.v, v3.x).
pub fn format_field_access(model: &SemanticModel, field_name: &str, type_name: &str) -> Option<String> {
    let normalized = normalize_type_name(type_name);
    // Check custom structs/classes in the model
    for sym in &model.symbols {
        if sym.name == normalized && (sym.kind == SymbolKind::Struct || sym.kind == SymbolKind::Class) {
            for f in &sym.fields {
                if f.name == field_name {
                    let kind_str = if sym.kind == SymbolKind::Struct { "struct" } else { "class" };
                    let mut md = format!("```enma\n{}.{}\n```\n", type_name, field_name);
                    md.push_str(&format!("**field** `{}::{}`", normalized, field_name));
                    if let Some(ref ft) = f.field_type {
                        md.push_str(&format!(" → `{}`", ft));
                    }
                    md.push_str(&format!("\n\nDefined in {} `{}`", kind_str, normalized));
                    return Some(md);
                }
            }
        }
    }
    None
}

/// Format hover for a FIELD access on a math type from the type DB (e.g. v3.x, qid.w).
pub fn format_math_field_hover(db: &TypeDatabase, field_name: &str, type_name: &str) -> Option<String> {
    let normalized = normalize_type_name(type_name);
    if let Some(mt) = db.math_types.get(normalized) {
        if mt.fields.iter().any(|f| f == field_name) {
            let mut md = format!("```enma\n{}.{}\n```\n", type_name, field_name);
            md.push_str(&format!("**field** `{}::{}`", normalized, field_name));
            md.push_str(&format!("\n\nComponent of built-in type `{}`", normalized));
            return Some(md);
        }
    }
    None
}

/// Format hover for a method on a CUSTOM struct/class from the semantic model.
pub fn format_custom_struct_method(model: &SemanticModel, method_name: &str, type_name: &str) -> String {
    eprintln!("[custom_method] looking for {}.{}() in model ({} symbols)", type_name, method_name, model.symbols.len());
    for sym in &model.symbols {
        if sym.name == type_name && (sym.kind == SymbolKind::Struct || sym.kind == SymbolKind::Class) {
            eprintln!("[custom_method] found {} '{}' with {} methods: {:?}",
                if sym.kind == SymbolKind::Struct { "struct" } else { "class" },
                sym.name, sym.methods.len(),
                sym.methods.iter().map(|m| m.name.clone()).collect::<Vec<_>>());
            for m in &sym.methods {
                if m.name == method_name {
                    let kind_str = if sym.kind == SymbolKind::Struct { "struct" } else { "class" };
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
    eprintln!("[custom_method] struct/class '{}' not found in model symbols", type_name);
    String::new()
}

/// Format hover for a method on a SPECIFIC type (receiver type known).
pub fn format_method_hover_for_type(db: &TypeDatabase, method_name: &str, type_name: &str) -> String {
    let mut md = String::new();
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
pub fn format_method_hover_all(db: &TypeDatabase, method_name: &str) -> String {
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

/// Type database hover for bare identifiers - functions, types, primitives, keywords.
/// Does NOT search methods (methods only fire for .access context).
pub fn format_type_db_hover_bare(db: &TypeDatabase, name: &str) -> String {
    format_type_db_hover_inner(db, name, false)
}

#[allow(dead_code)]
pub fn format_type_db_hover(db: &TypeDatabase, name: &str) -> String {
    format_type_db_hover_inner(db, name, true)
}

fn format_type_db_hover_inner(db: &TypeDatabase, name: &str, include_methods: bool) -> String {
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
                        md.push_str(&format!(" - {}", m.doc));
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

    if db.is_primitive(name) {
        let doc = db.get_keyword_doc(name).unwrap_or("");
        if !doc.is_empty() {
            return format!("```enma\n{}\n```\n**primitive type** `{}`\n\n{}", name, name, doc);
        }
        return format!("```enma\n{}\n```\n**primitive type** `{}`", name, name);
    }

    if let Some(doc) = db.get_keyword_doc(name) {
        let label = if db.keywords.contains(&name.to_string()) { "keyword" } else { "operator" };
        return format!("```enma\n{}\n```\n**language {}** `{}`\n\n{}", name, label, name, doc);
    }

    if let Some(stripped) = name.strip_suffix("[]") {
        if let Some(doc) = db.get_keyword_doc(stripped) {
            return format!("```enma\n{}\n```\n**language operator** `{}`\n\n{}", name, name, doc);
        }
    }

    String::new()
}

#[derive(Debug)]
pub enum HoverContext {
    /// Preceded by `.` - identifier is a method/property name on a receiver.
    MethodAccess { receiver: Option<String> },
    /// Bare identifier - could be variable, function, type, or keyword reference.
    BareIdentifier,
}

/// Detect what kind of token we're hovering over by looking at the source text around it.
pub fn detect_context(node: tree_sitter::Node, source: &str) -> HoverContext {
    let byte = node.start_byte();
    if byte == 0 { return HoverContext::BareIdentifier; }

    let current_text = &source[node.start_byte()..node.end_byte()];
    let before = &source[..byte];

    let mut search_end = byte;
    loop {
        let segment = &before[..search_end];
        let Some(dot_pos) = segment.rfind('.') else { break };
        let between = &segment[dot_pos + 1..];
        if between.trim().is_empty() {
            let before_dot = &before[..dot_pos].trim_end();
            // Strip trailing subscript: cs[0] → cs. Only strip if the subscript
            // brackets are on the same "expression" (no ; or newline between [ and .)
            let base = if let Some(bracket_pos) = before_dot.rfind('[') {
                let between_bracket_and_dot = &before_dot[bracket_pos..];
                if between_bracket_and_dot.contains('\n') || between_bracket_and_dot.contains(';') {
                    // Bracket is from a different statement - don't strip
                    before_dot.to_string()
                } else {
                    before_dot[..bracket_pos].trim_end().to_string()
                }
            } else {
                before_dot.to_string()
            };
            let receiver = base
                .rsplit(|c: char| !c.is_alphanumeric() && c != '_')
                .next()
                .unwrap_or("")
                .to_string();
            return HoverContext::MethodAccess {
                receiver: if receiver.is_empty() { None } else { Some(receiver) },
            };
        }
        search_end = dot_pos;
    }
    HoverContext::BareIdentifier
}

/// Strip generic parameters, array brackets, pointers, and references from a type name.
/// "int64[]" → "array" (T[] is syntactic sugar for array<T>)
/// "Cell*" → "Cell", "int64&" → "int64"
pub fn normalize_type_name(type_name: &str) -> &str {
    let s = type_name.trim_end_matches('*').trim_end_matches('&');
    if s.ends_with("[]") {
        return "array";
    }
    if let Some(pos) = s.find('<') {
        &s[..pos]
    } else {
        s
    }
}

pub fn resolve_type_of_name(name: &str, model: &SemanticModel, pos: Position) -> Option<String> {
    // Prefer the declaration closest to (but before) pos - handles shadowing
    model.symbols.iter()
        .filter(|s| s.name == name)
        .filter(|s| matches!(s.kind, SymbolKind::Variable | SymbolKind::Parameter | SymbolKind::Struct | SymbolKind::Class | SymbolKind::Enum | SymbolKind::Interface))
        .filter(|s| s.range.start <= pos)
        .max_by_key(|s| (s.range.start.line, s.range.start.character))
        .and_then(|s| match s.kind {
            SymbolKind::Variable | SymbolKind::Parameter => {
                s.var_type.as_ref().map(|t| normalize_type_name(t).to_string())
            }
            SymbolKind::Struct | SymbolKind::Class |
            SymbolKind::Enum | SymbolKind::Interface => {
                Some(s.name.clone())
            }
            _ => None,
        })
}

/// Standalone hover resolution - testable without the LSP server.
pub fn resolve_hover(
    name: &str,
    pos: Position,
    is_ident: bool,
    ctx: &HoverContext,
    model: &SemanticModel,
    db: &TypeDatabase,
) -> Option<(String, String)> {
    if let HoverContext::MethodAccess { receiver } = ctx {
        let receiver_type = receiver.as_ref()
            .and_then(|r| resolve_type_of_name(r, model, pos));

        let method_md = if let Some(ref rt) = receiver_type {
            let md = format_method_hover_for_type(db, name, rt);
            if !md.is_empty() { md }
            else {
                let custom = format_custom_struct_method(model, name, rt);
                if !custom.is_empty() { custom }
                else { format_method_hover_all(db, name) }
            }
        } else {
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

        // Method not found - check if it's a field on the receiver's type
        if let Some(ref recv) = receiver {
            if let Some(recv_type) = resolve_type_of_name(recv, model, pos) {
                if let Some(field_md) = format_field_access(model, name, &recv_type) {
                    return Some((field_md, format!("field on {}", recv_type)));
                }
                if let Some(field_md) = format_math_field_hover(db, name, &recv_type) {
                    return Some((field_md, format!("field on {}", recv_type)));
                }
            }
            // Also try raw receiver name as a type
            if let Some(field_md) = format_field_access(model, name, recv) {
                return Some((field_md, format!("field on {}", recv)));
            }
            if let Some(field_md) = format_math_field_hover(db, name, recv) {
                return Some((field_md, format!("field on {}", recv)));
            }
        }
    }

    if is_ident {
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

    match ctx {
        HoverContext::BareIdentifier => {
            let db_md = format_type_db_hover_bare(db, name);
            if !db_md.is_empty() {
                return Some((db_md, "type-db".into()));
            }
        }
        HoverContext::MethodAccess { .. } => {
            let db_md = format_method_hover_all(db, name);
            if !db_md.is_empty() {
                return Some((db_md, "type-db-method".into()));
            }
            let db_md2 = format_type_db_hover_bare(db, name);
            if !db_md2.is_empty() {
                return Some((db_md2, "type-db".into()));
            }
        }
    }

    None
}

pub fn range_contains(range: &Range, pos: Position) -> bool {
    pos >= range.start && pos <= range.end
}

pub fn find_named_leaf(node: tree_sitter::Node, pos: Position) -> tree_sitter::Node {
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

pub fn node_range(node: &tree_sitter::Node) -> Range {
    let start = node.start_position();
    let end = node.end_position();
    Range {
        start: Position { line: start.row as u32, character: start.column as u32 },
        end: Position { line: end.row as u32, character: end.column as u32 },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::type_db::TypeDatabase;
    use crate::semantic::SemanticModel;
    use tower_lsp::lsp_types::Position;

    fn setup_test(source: &str) -> (SemanticModel, TypeDatabase) {
        let mut parser = tree_sitter::Parser::new();
        unsafe {
            let lang_fn = crate::parser::tree_sitter_enma;
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
        let call_pos = Position { line: 5, character: 4 };
        let result = resolve_hover("check", call_pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some());
        let (md, path) = result.unwrap();
        assert!(path.contains("ref-site"));
        assert!(md.contains("check"));
        assert!(md.contains("label"));
        assert!(md.contains("ok"));
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
        let def_pos = Position { line: 0, character: 5 };
        let result = resolve_hover("check", def_pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some());
        let (_, path) = result.unwrap();
        assert!(path.contains("decl-site"));
    }

    #[test]
    fn test_resolve_hover_builtin_type() {
        let source = r#"int64 main() {
    window_info_t info;
    return 0;
}
"#;
        let (model, db) = setup_test(source);
        let pos = Position { line: 1, character: 4 };
        let result = resolve_hover("window_info_t", pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some());
    }

    #[test]
    fn test_resolve_hover_array_type() {
        let source = r#"int64 main() {
    int64[] arr;
    return 0;
}
"#;
        let (model, db) = setup_test(source);
        let pos = Position { line: 1, character: 4 };
        let result = resolve_hover("int64", pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some());
    }

    #[test]
    fn test_resolve_hover_method_name() {
        let source = r#"int64 main() {
    string s = "hello";
    int64 n = s.length();
    return n;
}
"#;
        let (model, db) = setup_test(source);
        let pos = Position { line: 2, character: 16 };
        let ctx = HoverContext::MethodAccess { receiver: Some("s".into()) };
        let result = resolve_hover("length", pos, true, &ctx, &model, &db);
        assert!(result.is_some());
        let (md, path) = result.unwrap();
        assert!(path.contains("method on string"));
        assert!(md.contains("string::length"));
    }

    #[test]
    fn test_variable_over_method_priority() {
        let source = r#"int64 main() {
    int64 first = 42;
    int64 result = first + 1;
    return result;
}
"#;
        let (model, db) = setup_test(source);
        let pos = Position { line: 2, character: 18 };
        let result = resolve_hover("first", pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some());
        let (_, path) = result.unwrap();
        assert!(path.contains("Variable"));
        assert!(!path.contains("method"));
    }

    #[test]
    fn test_method_on_specific_receiver_type() {
        let source = r#"int64 main() {
    string name = "hello";
    int64 len = name.length();
    return len;
}
"#;
        let (model, db) = setup_test(source);
        let pos = Position { line: 2, character: 18 };
        let ctx = HoverContext::MethodAccess { receiver: Some("name".into()) };
        let result = resolve_hover("length", pos, true, &ctx, &model, &db);
        assert!(result.is_some());
        let (md, _) = result.unwrap();
        assert!(md.contains("string::length") || md.contains("string.length"));
        let length_count = md.matches("::length").count();
        assert!(length_count <= 2);
    }

    #[test]
    fn test_generic_type_method_resolution() {
        let source = r#"int64 main() {
    array<window_info_t> wins;
    int64 n = wins.length();
    return n;
}
"#;
        let (model, db) = setup_test(source);
        let pos = Position { line: 2, character: 18 };
        let ctx = HoverContext::MethodAccess { receiver: Some("wins".into()) };
        let result = resolve_hover("length", pos, true, &ctx, &model, &db);
        assert!(result.is_some());
        let (md, path) = result.unwrap();
        assert!(md.contains("array::length") || md.contains("array.length"));
        let count = md.matches("::length").count();
        assert!(count <= 2);
    }

    #[test]
    fn test_normalize_type_name() {
        assert_eq!(normalize_type_name("array<window_info_t>"), "array");
        assert_eq!(normalize_type_name("map<string,int64>"), "map");
        assert_eq!(normalize_type_name("int64[]"), "array");
        assert_eq!(normalize_type_name("string[][]"), "array");
        assert_eq!(normalize_type_name("float64[]"), "array");
        assert_eq!(normalize_type_name("window_info_t"), "window_info_t");
        assert_eq!(normalize_type_name("vec3"), "vec3");
    }

    #[test]
    fn test_window_info_t_first_method_pid() {
        let source = r#"int64 main() {
    window_info_t first;
    int64 p = first.pid();
    return p;
}
"#;
        let (model, db) = setup_test(source);
        let pos = Position { line: 2, character: 20 };
        let ctx = HoverContext::MethodAccess { receiver: Some("first".into()) };
        let result = resolve_hover("pid", pos, true, &ctx, &model, &db);
        assert!(result.is_some());
        let (md, _) = result.unwrap();
        assert!(md.contains("window_info_t::pid") || md.contains("window_info_t.pid"));
        let proc_count = md.matches("proc_t::pid").count();
        assert_eq!(proc_count, 0);
    }

    #[test]
    fn test_custom_struct_method_hover() {
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
        let pos = Position { line: 8, character: 7 };
        let ctx = HoverContext::MethodAccess { receiver: Some("c1".into()) };
        let result = resolve_hover("inc", pos, true, &ctx, &model, &db);
        assert!(result.is_some());
        let (md, _) = result.unwrap();
        assert!(md.contains("Cell::inc") || md.contains("Cell.inc"));
        let atomic = md.matches("atomic").count();
        assert_eq!(atomic, 0);
    }

    #[test]
    fn test_imported_struct_method_merge() {
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
        main_model.merge_import(lib_model, "lib.em");
        let pos = Position { line: 2, character: 7 };
        let ctx = HoverContext::MethodAccess { receiver: Some("c1".into()) };
        let result = resolve_hover("inc", pos, true, &ctx, &main_model, &db);
        assert!(result.is_some());
        let (md, _) = result.unwrap();
        assert!(md.contains("Cell::inc") || md.contains("Cell.inc"));
        let atomic = md.matches("atomic").count();
        assert_eq!(atomic, 0);
    }

    #[test]
    fn test_bare_identifier_never_shows_methods() {
        let source = r#"int64 main() {
    int64 length = 10;
    return length;
}
"#;
        let (model, db) = setup_test(source);
        let pos = Position { line: 2, character: 11 };
        let result = resolve_hover("length", pos, true, &HoverContext::BareIdentifier, &model, &db);
        assert!(result.is_some());
        let (md, path) = result.unwrap();
        assert!(path.contains("Variable"));
        assert!(!md.contains("string::length") && !md.contains("array::length") && !md.contains("method"));
    }
}
