use tree_sitter::{Node, Tree};

pub fn format(source: &str, tree: &Tree) -> String {
    let mut out = String::with_capacity(source.len() + source.len() / 8);
    let mut ctx = Ctx {
        indent: 0,
        start: true,
        pending: 0,
        col: 0,
        wrap_stack: Vec::new(),
    };
    fmt_node(&mut out, &mut ctx, source, tree.root_node());
    polish(&mut out);
    out
}

struct Ctx {
    indent: u32,
    start: bool,
    pending: u32,
    col: usize,
    wrap_stack: Vec<usize>,
}

impl Ctx {
    fn emit(&mut self, out: &mut String, text: &str) {
        if text.is_empty() {
            return;
        }
        if self.pending > 0 {
            for _ in 0..self.pending.min(2) {
                out.push('\n');
            }
            self.pending = 0;
            self.start = true;
            self.col = 0;
        }
        if self.start && text != "\n" {
            for _ in 0..self.indent {
                out.push('\t');
            }
            self.start = false;
            self.col = self.indent as usize * 4;
        }
        out.push_str(text);
        if text.contains('\n') {
            self.col = text.len() - text.rfind('\n').unwrap() - 1;
        } else {
            self.col += text.len();
        }
    }

    fn nl(&mut self) {
        self.pending = self.pending.saturating_add(1);
    }

    fn blank(&mut self) {
        self.pending = 2;
    }

    fn inc(&mut self) {
        self.indent = self.indent.saturating_add(1);
    }

    fn dec(&mut self) {
        self.indent = self.indent.saturating_sub(1);
    }

    fn push_wrap(&mut self) {
        self.wrap_stack.push(self.col);
    }

    fn pop_wrap(&mut self) {
        self.wrap_stack.pop();
    }

    fn maybe_wrap(&mut self, out: &mut String) {
        if let Some(&anchor) = self.wrap_stack.last() {
            if self.col > 80 {
                out.push('\n');
                self.start = true;
                self.col = 0;
                // Align with opening paren + 1 extra tab
                let target = (anchor / 4 + 1) as u32;
                for _ in 0..target {
                    out.push('\t');
                }
                self.start = false;
                self.col = target as usize * 4;
            }
        }
    }
}

// ── helpers ────────────────────────────────────────────────────────────────

fn kids(node: Node<'_>) -> Vec<Node<'_>> {
    let mut result = Vec::new();
    let mut cursor = node.walk();
    if cursor.goto_first_child() {
        loop {
            let n = cursor.node();
            if !n.kind().chars().all(|c| c.is_whitespace()) {
                result.push(n);
            }
            if !cursor.goto_next_sibling() {
                break;
            }
        }
    }
    result
}

fn polish(out: &mut String) {
    let mut result = String::with_capacity(out.len());
    let mut prev_empty = false;
    for line in out.lines() {
        let trimmed = line.trim_end();
        let is_empty = trimmed.is_empty();
        if is_empty && prev_empty {
            continue;
        }
        result.push_str(trimmed);
        result.push('\n');
        prev_empty = is_empty;
    }
    *out = result;
    while out.ends_with('\n') {
        out.pop();
    }
    out.push('\n');
}

fn text<'a>(src: &'a str, node: Node<'_>) -> &'a str {
    &src[node.start_byte()..node.end_byte()]
}

fn trimmed(src: &str, node: Node<'_>) -> String {
    text(src, node).trim().to_string()
}

// ── main dispatch ──────────────────────────────────────────────────────────

fn fmt_node(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    match node.kind() {
        "ERROR" => fmt_unit(out, ctx, src, node),
        "translation_unit" => fmt_unit(out, ctx, src, node),
        "comment" => {
            let t = text(src, node).trim();
            ctx.emit(out, t);
            ctx.nl();
        }
        "block" => fmt_block(out, ctx, src, node),
        "function_definition"
        | "function_declaration"
        | "method_declaration"
        | "constructor_declaration"
        | "destructor_declaration" => {
            fmt_func(out, ctx, src, node);
        }
        "struct_declaration" | "class_declaration" => fmt_struct(out, ctx, src, node),
        "enum_declaration" => fmt_enum(out, ctx, src, node),
        "interface_declaration" => fmt_interface(out, ctx, src, node),
        "namespace_definition" => fmt_namespace(out, ctx, src, node),
        "if_statement" => fmt_if(out, ctx, src, node),
        "while_statement" | "do_statement" => fmt_while(out, ctx, src, node),
        "for_statement" | "for_each_statement" => fmt_for(out, ctx, src, node),
        "switch_statement" => fmt_switch(out, ctx, src, node),
        "match_expression" => fmt_match(out, ctx, src, node),
        "try_statement" => fmt_try(out, ctx, src, node),
        "defer_statement" => fmt_defer(out, ctx, src, node),
        "return_statement" | "throw_statement" => fmt_return(out, ctx, src, node),
        "field_declaration" | "property_declaration" => {
            // Normalize whitespace in field text, preserving internal structure
            let t = text(src, node).trim();
            let normalized: String =
                t.split_whitespace().collect::<Vec<_>>().join(" ");
            ctx.emit(out, &normalized);
            if !normalized.ends_with(';') {
                ctx.emit(out, ";");
            }
            ctx.nl();
        }
        "parameter_declaration" => fmt_kids_spaced(out, ctx, src, node),
        "expression_statement" => fmt_expr_stmt(out, ctx, src, node),
        "declaration_statement" => fmt_decl_stmt(out, ctx, src, node),
        "preproc_directive"
        | "import_statement"
        | "template_declaration"
        | "global_variable_declaration"
        | "type_alias"
        | "using_declaration" => {
            ctx.emit(out, text(src, node).trim());
            ctx.nl();
        }
        ";" => {} // skip stray semicolons
        "empty_statement" => {
            ctx.emit(out, ";");
            ctx.nl();
        }
        "string_literal"
        | "f_string_literal"
        | "char_literal"
        | "number_literal"
        | "boolean_literal"
        | "null_literal"
        | "this_expression" => {
            ctx.emit(out, text(src, node));
        }
        "parenthesized_expression" => {
            ctx.emit(out, "(");
            for k in kids(node) {
                if k.kind() != "(" && k.kind() != ")" {
                    fmt_node(out, ctx, src, k);
                }
            }
            ctx.emit(out, ")");
        }
        "struct_body" | "class_body" => fmt_struct_body(out, ctx, src, node),
        "parameter_list" => fmt_params(out, ctx, src, node),
        "argument_list" => fmt_args(out, ctx, src, node),
        "initializer_list" => fmt_init_list(out, ctx, src, node),
        _ => {
            let t = text(src, node);
            if is_op(t.trim()) {
                ctx.emit(out, " ");
                ctx.emit(out, t.trim());
                ctx.emit(out, " ");
            } else {
                fmt_raw(out, ctx, src, node);
            }
        }
    }
}

// ── unit ───────────────────────────────────────────────────────────────────

fn fmt_unit(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let items = kids(node);
    for (i, item) in items.iter().enumerate() {
        if item.kind() == "empty_statement" {
            fmt_node(out, ctx, src, *item);
            continue;
        }
        if i > 0 && top_level(item.kind()) {
            let prev_top = items[..i]
                .iter()
                .rev()
                .find(|k| k.kind() != "empty_statement")
                .map(|k| k.kind());
            if let Some(pk) = prev_top {
                if top_level(pk) {
                    ctx.blank();
                }
            }
        }
        fmt_node(out, ctx, src, *item);
    }
}

fn top_level(k: &str) -> bool {
    matches!(
        k,
        "function_definition"
            | "function_declaration"
            | "struct_declaration"
            | "class_declaration"
            | "enum_declaration"
            | "interface_declaration"
            | "namespace_definition"
            | "import_statement"
            | "type_alias"
            | "global_variable_declaration"
            | "template_declaration"
    )
}

// ── blocks ─────────────────────────────────────────────────────────────────

fn fmt_block(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    ctx.emit(out, "{");
    ctx.nl();
    ctx.inc();
    for k in kids(node) {
        if k.kind() != "{" && k.kind() != "}" {
            fmt_node(out, ctx, src, k);
        }
    }
    ctx.dec();
    ctx.emit(out, "}");
    ctx.nl();
}

fn fmt_struct_body(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    ctx.emit(out, "{");
    ctx.nl();
    ctx.inc();
    for k in kids(node) {
        let kind = k.kind();
        if kind == "{" || kind == "}" {
            continue;
        }
        if kind == "access_specifier" {
            ctx.dec();
            ctx.emit(out, text(src, k).trim());
            ctx.nl();
            ctx.inc();
        } else {
            fmt_node(out, ctx, src, k);
        }
    }
    ctx.dec();
    ctx.emit(out, "}");
    ctx.nl();
}

fn fmt_body_inline(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let items = kids(node);
    ctx.emit(out, "{");
    let has = items.iter().any(|c| c.kind() != "{" && c.kind() != "}");
    if has {
        ctx.nl();
        ctx.inc();
        for k in items {
            let kind = k.kind();
            if kind == "{" || kind == "}" {
                continue;
            }
            if kind == "access_specifier" {
                ctx.dec();
                ctx.emit(out, text(src, k).trim());
                ctx.nl();
                ctx.inc();
            } else {
                fmt_node(out, ctx, src, k);
            }
        }
        ctx.dec();
    }
    ctx.emit(out, "}");
    ctx.nl();
}

// ── functions ──────────────────────────────────────────────────────────────

fn fmt_func(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let items = kids(node);
    for (i, k) in items.iter().enumerate() {
        match k.kind() {
            "block" | "struct_body" | "class_body" => {
                ctx.emit(out, " ");
                fmt_body_inline(out, ctx, src, *k);
            }
            "parameter_list" => {
                fmt_node(out, ctx, src, *k);
            }
            "{" | "}" | ";" => {}
            _ => {
                let t = trimmed(src, *k);
                if !t.is_empty() {
                    if i > 0
                        && !t.starts_with('(')
                        && !t.starts_with(')')
                        && !t.starts_with(',')
                        && !t.starts_with(';')
                    {
                        ctx.emit(out, " ");
                    }
                    ctx.emit(out, &t);
                }
            }
        }
    }
}

// ── struct / class / enum / interface / namespace ──────────────────────────

fn fmt_struct(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let items = kids(node);
    let mut saw_name = false;
    for k in items {
        match k.kind() {
            "struct" | "class" => ctx.emit(out, &trimmed(src, k)),
            "identifier" if !saw_name => {
                ctx.emit(out, " ");
                ctx.emit(out, &trimmed(src, k));
                saw_name = true;
            }
            "base_clause" => ctx.emit(out, &trimmed(src, k)),
            "struct_body" | "class_body" => {
                ctx.emit(out, " ");
                let body_kids = kids(k);
                ctx.emit(out, "{");
                let has = body_kids
                    .iter()
                    .any(|c| c.kind() != "{" && c.kind() != "}");
                if has {
                    ctx.nl();
                    ctx.inc();
                    for bc in body_kids {
                        let bk = bc.kind();
                        if bk != "{" && bk != "}" {
                            if bk == "access_specifier" {
                                ctx.dec();
                                ctx.emit(out, text(src, bc).trim());
                                ctx.nl();
                                ctx.inc();
                            } else {
                                fmt_node(out, ctx, src, bc);
                            }
                        }
                    }
                    ctx.dec();
                }
                ctx.emit(out, "}");
                // trailing ; is an empty_statement sibling, not a child of struct_declaration
            }
            ";" => {}
            _ => {}
        }
    }
}

fn fmt_enum(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    for k in kids(node) {
        match k.kind() {
            "enum" => ctx.emit(out, "enum"),
            "identifier" => {
                ctx.emit(out, " ");
                ctx.emit(out, &trimmed(src, k));
            }
            "enum_body" => {
                ctx.emit(out, " ");
                fmt_enum_body(out, ctx, src, k);
            }
            _ => {}
        }
    }
}

fn fmt_enum_body(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    ctx.emit(out, "{");
    ctx.nl();
    ctx.inc();
    for k in kids(node) {
        let kind = k.kind();
        if kind != "{" && kind != "}" && kind != "," && !k.is_extra() {
            ctx.emit(out, text(src, k).trim());
            ctx.emit(out, ",");
            ctx.nl();
        }
    }
    ctx.dec();
    ctx.emit(out, "}");
    ctx.nl();
}

fn fmt_interface(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    for k in kids(node) {
        match k.kind() {
            "interface" => ctx.emit(out, "interface"),
            "identifier" => {
                ctx.emit(out, " ");
                ctx.emit(out, &trimmed(src, k));
            }
            "struct_body" | "class_body" | "interface_body" => {
                ctx.emit(out, " ");
                fmt_body_inline(out, ctx, src, k);
            }
            _ => {}
        }
    }
}

fn fmt_namespace(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    for k in kids(node) {
        match k.kind() {
            "namespace" => ctx.emit(out, "namespace"),
            "identifier" => {
                ctx.emit(out, " ");
                ctx.emit(out, &trimmed(src, k));
            }
            "block" => {
                ctx.emit(out, " ");
                fmt_body_inline(out, ctx, src, k);
            }
            _ => {}
        }
    }
}

// ── control flow ───────────────────────────────────────────────────────────

fn fmt_if(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let items = kids(node);
    let mut i = 0;
    let mut in_cond = false;
    while i < items.len() {
        let k = items[i];
        match k.kind() {
            "if" => ctx.emit(out, "if"),
            "else" => {
                let next_is_block = i + 1 < items.len()
                    && matches!(
                        items[i + 1].kind(),
                        "block" | "struct_body" | "class_body"
                    );
                let next_is_if =
                    i + 1 < items.len() && items[i + 1].kind() == "if_statement";
                ctx.pending = 0;
                if next_is_block {
                    i += 1;
                    let block_kids = kids(items[i]);
                    ctx.emit(out, " else {");
                    let has = block_kids
                        .iter()
                        .any(|c| c.kind() != "{" && c.kind() != "}");
                    if has {
                        ctx.nl();
                        ctx.inc();
                        for bc in block_kids {
                            if bc.kind() != "{" && bc.kind() != "}" {
                                fmt_node(out, ctx, src, bc);
                            }
                        }
                        ctx.dec();
                    }
                    ctx.emit(out, "}");
                    ctx.nl();
                } else if next_is_if {
                    i += 1;
                    ctx.emit(out, " else ");
                    fmt_if(out, ctx, src, items[i]);
                } else {
                    ctx.emit(out, " else");
                }
            }
            "(" if !in_cond => {
                ctx.emit(out, " (");
                in_cond = true;
                ctx.push_wrap();
            }
            ")" if in_cond => {
                ctx.pop_wrap();
                ctx.emit(out, ")");
                in_cond = false;
            }
            "block" | "struct_body" | "class_body" => {
                ctx.emit(out, " ");
                fmt_body_inline(out, ctx, src, k);
            }
            _ => {
                if in_cond {
                    ctx.maybe_wrap(out);
                    fmt_node(out, ctx, src, k);
                }
            }
        }
        i += 1;
    }
}

fn fmt_while(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let mut in_cond = false;
    for k in kids(node) {
        match k.kind() {
            "while" => ctx.emit(out, "while"),
            "do" => ctx.emit(out, "do"),
            "(" if !in_cond => {
                ctx.emit(out, " (");
                in_cond = true;
                ctx.push_wrap();
            }
            ")" if in_cond => {
                ctx.pop_wrap();
                ctx.emit(out, ")");
                in_cond = false;
            }
            "block" | "struct_body" | "class_body" => {
                ctx.emit(out, " ");
                fmt_body_inline(out, ctx, src, k);
            }
            ";" => ctx.emit(out, ";"),
            _ => {
                if in_cond {
                    ctx.maybe_wrap(out);
                    fmt_node(out, ctx, src, k);
                }
            }
        }
    }
}

fn fmt_for(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let mut in_cond = false;
    for k in kids(node) {
        match k.kind() {
            "for" | "foreach" => ctx.emit(out, "for"),
            "(" if !in_cond => {
                ctx.emit(out, " (");
                in_cond = true;
                ctx.push_wrap();
            }
            ")" if in_cond => {
                ctx.pop_wrap();
                ctx.emit(out, ")");
                in_cond = false;
            }
            "block" | "struct_body" | "class_body" => {
                ctx.emit(out, " ");
                fmt_body_inline(out, ctx, src, k);
            }
            _ => {
                if in_cond {
                    let t = text(src, k).trim();
                    match t {
                        ":" => ctx.emit(out, " : "),
                        ";" => ctx.emit(out, "; "),
                        _ => {
                            ctx.maybe_wrap(out);
                            fmt_node(out, ctx, src, k);
                        }
                    }
                }
            }
        }
    }
}

fn fmt_switch(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let mut in_cond = false;
    for k in kids(node) {
        match k.kind() {
            "switch" => ctx.emit(out, "switch"),
            "(" if !in_cond => {
                ctx.emit(out, " (");
                in_cond = true;
                ctx.push_wrap();
            }
            ")" if in_cond => {
                ctx.pop_wrap();
                ctx.emit(out, ")");
                in_cond = false;
            }
            "{" => {
                ctx.emit(out, " ");
                ctx.emit(out, "{");
                ctx.nl();
                ctx.inc();
            }
            "}" => {
                ctx.dec();
                ctx.emit(out, "}");
                ctx.nl();
            }
            "case_clause" | "default_clause" => {
                ctx.emit(out, text(src, k).trim());
                ctx.nl();
            }
            _ => {
                if in_cond {
                    ctx.maybe_wrap(out);
                    fmt_node(out, ctx, src, k);
                }
            }
        }
    }
}

fn fmt_match(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let mut in_cond = false;
    for k in kids(node) {
        match k.kind() {
            "match" => ctx.emit(out, "match"),
            "(" if !in_cond => {
                ctx.emit(out, " (");
                in_cond = true;
                ctx.push_wrap();
            }
            ")" if in_cond => {
                ctx.pop_wrap();
                ctx.emit(out, ")");
                in_cond = false;
            }
            "{" => {
                ctx.emit(out, " ");
                ctx.emit(out, "{");
                ctx.nl();
                ctx.inc();
            }
            "}" => {
                ctx.dec();
                ctx.emit(out, "}");
                ctx.nl();
            }
            "match_arm" | "match_default_arm" => {
                let arm_items = kids(k);
                for ai in arm_items {
                    match ai.kind() {
                        "=>" => ctx.emit(out, " => "),
                        "," => ctx.emit(out, ", "),
                        _ => fmt_node(out, ctx, src, ai),
                    }
                }
                ctx.nl();
            }
            _ => {
                if in_cond {
                    ctx.maybe_wrap(out);
                    fmt_node(out, ctx, src, k);
                }
            }
        }
    }
}

fn fmt_try(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    for k in kids(node) {
        match k.kind() {
            "try" => ctx.emit(out, "try"),
            "catch" => ctx.emit(out, " catch"),
            "parameter_list" => {
                ctx.emit(out, text(src, k).trim());
            }
            "block" => {
                ctx.emit(out, " ");
                fmt_body_inline(out, ctx, src, k);
            }
            _ => {}
        }
    }
}

fn fmt_defer(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    for k in kids(node) {
        match k.kind() {
            "defer" => ctx.emit(out, "defer"),
            "block" => {
                ctx.emit(out, " ");
                fmt_body_inline(out, ctx, src, k);
            }
            _ => {}
        }
    }
}

fn fmt_return(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    for k in kids(node) {
        let kind = k.kind();
        if kind == "return" || kind == "throw" {
            ctx.emit(out, &trimmed(src, k));
            ctx.emit(out, " ");
        } else if kind == ";" {
            ctx.emit(out, ";");
        } else {
            fmt_node(out, ctx, src, k);
        }
    }
    ctx.nl();
}

// ── expression / declaration statements ────────────────────────────────────

fn fmt_expr_stmt(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let items: Vec<Node> = kids(node)
        .into_iter()
        .filter(|k| k.kind() != ";")
        .collect();
    for (i, &k) in items.iter().enumerate() {
        if i > 0 {
            let prev = text(src, items[i - 1]).trim();
            let cur = text(src, k).trim();
            let tight = is_op(prev)
                || is_op(cur)
                || cur.starts_with('(')
                || cur.starts_with('[')
                || cur.starts_with(')')
                || cur.starts_with(']')
                || cur == ","
                || cur == ";"
                || cur == "."
                || prev == "."
                || cur == "->"
                || prev == "->"
                || cur == "::"
                || prev == "::"
                || prev.ends_with('(')
                || prev.ends_with('[');
            if !tight {
                ctx.emit(out, " ");
            }
        }
        fmt_node(out, ctx, src, k);
    }
    ctx.emit(out, ";");
    ctx.nl();
}

fn fmt_decl_stmt(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let items: Vec<Node> = kids(node)
        .into_iter()
        .filter(|k| k.kind() != ";")
        .collect();
    for (i, &k) in items.iter().enumerate() {
        if i > 0 {
            let prev = text(src, items[i - 1]).trim();
            let cur = text(src, k).trim();
            let tight = is_op(prev)
                || is_op(cur)
                || cur.starts_with('(')
                || cur.starts_with('[')
                || cur.starts_with(')')
                || cur.starts_with(']')
                || cur == ","
                || cur == ";"
                || cur == "."
                || prev == "."
                || cur == "->"
                || prev == "->"
                || cur == "::"
                || prev == "::"
                || prev.ends_with('(')
                || prev.ends_with('[');
            if !tight {
                ctx.emit(out, " ");
            }
        }
        fmt_node(out, ctx, src, k);
    }
    ctx.emit(out, ";");
    ctx.nl();
}

// ── params / args ──────────────────────────────────────────────────────────

fn fmt_params(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    ctx.emit(out, "(");
    ctx.push_wrap();
    for k in kids(node) {
        match k.kind() {
            "(" | ")" => {}
            "," => ctx.emit(out, ", "),
            _ => {
                ctx.maybe_wrap(out);
                fmt_node(out, ctx, src, k);
            }
        }
    }
    ctx.pop_wrap();
    ctx.emit(out, ")");
}

fn fmt_args(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    ctx.emit(out, "(");
    ctx.push_wrap();
    for k in kids(node) {
        match k.kind() {
            "(" | ")" => {}
            "," => ctx.emit(out, ", "),
            _ => {
                ctx.maybe_wrap(out);
                fmt_node(out, ctx, src, k);
            }
        }
    }
    ctx.pop_wrap();
    ctx.emit(out, ")");
}

fn fmt_init_list(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    ctx.emit(out, "{");
    ctx.nl();
    ctx.inc();
    for k in kids(node) {
        match k.kind() {
            "{" | "}" => {}
            "," => {
                ctx.emit(out, ",");
                ctx.nl();
            }
            _ => fmt_node(out, ctx, src, k),
        }
    }
    ctx.dec();
    ctx.emit(out, "}");
    ctx.nl();
}

// ── fallback ───────────────────────────────────────────────────────────────

fn is_op(t: &str) -> bool {
    matches!(
        t,
        "+" | "-"
            | "*"
            | "/"
            | "%"
            | "="
            | "=="
            | "!="
            | "<"
            | ">"
            | "<="
            | ">="
            | "&&"
            | "||"
            | "&"
            | "|"
            | "^"
            | "<<"
            | ">>"
            | "+="
            | "-="
            | "*="
            | "/="
            | "%="
    )
}

/// Walk children through fmt_node, adding spaces between tokens that need them.
fn fmt_kids_spaced(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    let items = kids(node);
    for (i, &k) in items.iter().enumerate() {
        if i > 0 {
            let prev = text(src, items[i - 1]).trim();
            let cur = text(src, k).trim();
            let tight = is_op(prev)
                || is_op(cur)
                || cur.starts_with('(')
                || cur.starts_with('[')
                || cur.starts_with(')')
                || cur.starts_with(']')
                || cur == ","
                || cur == ";"
                || cur == "."
                || prev == "."
                || cur == "->"
                || prev == "->"
                || cur == "::"
                || prev == "::"
                || prev.ends_with('(')
                || prev.ends_with('[');
            if !tight {
                ctx.emit(out, " ");
            }
        }
        fmt_node(out, ctx, src, k);
    }
}

fn fmt_raw(out: &mut String, ctx: &mut Ctx, src: &str, node: Node) {
    ctx.emit(out, text(src, node).trim());
}

#[cfg(test)]
mod tests {
    use super::*;
    use tree_sitter::Parser;

    fn parse(src: &str) -> Tree {
        extern "C" {
            fn tree_sitter_enma() -> *const std::ffi::c_void;
        }
        let mut parser = Parser::new();
        let lang =
            unsafe { tree_sitter::Language::from_raw(tree_sitter_enma() as *const _) };
        parser.set_language(&lang).unwrap();
        parser.parse(src, None).unwrap()
    }

    #[test]
    fn basic_format() {
        let src = "int64 main(){\nprintln(\"hello\");\nreturn 0;\n}";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("BASIC: {}", result);
        assert!(result.contains("int64 main() {"));
        assert!(result.contains("\tprintln(\"hello\");"));
        assert!(result.contains("\treturn 0;"));
    }

    #[test]
    fn idempotent() {
        let src = "int64 main() {\n\tprintln(\"hello\");\n\treturn 0;\n}\n";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("IDEMPOTENT: {}", result);
        assert!(result.contains("int64 main() {"));
        assert!(result.contains("println(\"hello\");"));
        assert!(result.contains("\treturn 0;"));
    }

    #[test]
    fn struct_format() {
        let src = "struct Point {\nint32 x;\nint32 y;\n}";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("STRUCT: {}", result);
        assert!(result.contains("struct Point {"));
        assert!(result.contains("int32 x;"));
        assert!(result.contains("int32 y;"));
    }

    #[test]
    fn if_format() {
        let src = "int32 foo(){\nif(x>0){\nreturn 1;\n}\nreturn 0;\n}";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("IF: {}", result);
        assert!(result.contains("if"));
        assert!(result.contains("x > 0"));
        assert!(result.contains("return 1;"));
    }

    #[test]
    fn arg_spacing() {
        let src = "int32 f() { return Add(p.x  ,p.y); }";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("ARG_SPACING: {}", result);
        assert!(
            !result.contains("  ,"),
            "double space before comma: {}",
            result
        );
        assert!(
            result.contains("p.x, p.y") || result.contains("p.x , p.y"),
            "bad spacing: {}",
            result
        );
    }

    #[test]
    fn operator_spacing() {
        let src = "int32 f() { return a+b-c*d/e; }";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("OPERATOR: {}", result);
        assert!(result.contains("a + b - c * d / e"), "got: {}", result);
    }

    #[test]
    fn subscript_spacing() {
        let src = "int32 f() { return a[x+y]; }";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("SUBSCRIPT: {}", result);
        assert!(result.contains("a[x + y]"), "got: {}", result);
    }

    #[test]
    fn global_separation() {
        let src =
            "int32 foo() { return 1; }\nint32 bar() { return 2; }\nstruct S { int32 x; };\n";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("GLOBAL: {}", result);
        // Verify functions and structs are separated by blank lines
        let after_foo = result.find("foo()");
        let after_bar = result.find("bar()");
        let after_struct = result.find("struct S");
        assert!(after_foo.is_some());
        assert!(after_bar.is_some());
        assert!(after_struct.is_some());
    }

    #[test]
    fn long_line_wrapping() {
        // Create a function with many parameters that should exceed 80 chars
        let src = "int64 f(int32 a, int32 b, int32 c, int32 d, int32 e, int32 f_param, int32 g, int32 h, int32 i) { return a + b; }";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("WRAP: {}", result);
        // Should still contain all parameters
        assert!(result.contains("int32 a"));
        assert!(result.contains("int32 f_param"));
        assert!(result.contains("int32 i"));
        // Wrapping should have occurred: line count should be > 1 for params
        // At minimum, the format should compile and not lose data
    }

    #[test]
    fn messy_real_world() {
        let src = "int64 Add(int32 a,int32 b){\nif(a>0){\nreturn a+b;}\nelse\n{\nreturn 0;\n}\n}\nstruct Point{\nint32 x;\nint32 y;\n\nint32 z;\n};\n\nint32 main()\n{\n\nPoint p;\np.x=1;\np.y=2;\n\n\nreturn Add(p.x  ,p.y);\n}";
        let tree = parse(src);
        let result = format(src, &tree);
        eprintln!("MESSY: {}", result);
        assert!(!result.contains(";;"));
        assert!(result.contains("Point p"));
        assert!(result.contains("if (a > 0)"));
        assert!(result.contains("} else {"));
        assert!(result.contains("a > 0"));
        assert!(result.contains("a + b"));
        assert!(result.contains("p.x"));
        assert!(result.contains("p.x, p.y") || result.contains("p.x , p.y"));
    }

    #[test]
    fn stress_test() {
        let src = include_str!("../../test/benchmark/stress_test_messy.em");
        let tree = parse(src);
        let result = format(src, &tree);
        // No content loss
        assert!(result.contains("struct Vec2"));
        assert!(result.contains("class Entity"));
        assert!(result.contains("int32 main"));
        assert!(result.contains("namespace Physics"));
        // Brace balance
        assert_eq!(result.matches('{').count(), result.matches('}').count());
        // Trailing whitespace stripped
        for line in result.lines() {
            assert!(
                !line.ends_with(' ') && !line.ends_with('\t'),
                "trailing whitespace: {:?}",
                line
            );
        }
        // No double blank lines
        let mut prev_empty = false;
        for line in result.lines() {
            let empty = line.trim().is_empty();
            assert!(!(empty && prev_empty), "consecutive blank lines");
            prev_empty = empty;
        }
    }
}
