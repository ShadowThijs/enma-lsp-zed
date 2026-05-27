use std::collections::HashSet;
use std::path::{Path, PathBuf};

use anyhow::Result;
use tree_sitter::Node;

use crate::parser::EnmaParser;

#[derive(Default)]
pub struct BundleOptions {
    pub strip_comments: bool,
}

pub struct BundleResult {
    pub source: String,
    pub warnings: Vec<String>,
}

/// Build the two candidate paths for an import: the exact path and the `.em`-appended path.
/// Does NOT check filesystem existence (pure path arithmetic).
pub(crate) fn build_import_candidates(base_dir: &Path, import_path: &str) -> (PathBuf, PathBuf) {
    let is_absolute = import_path.starts_with('/')
        || (import_path.len() >= 3
            && import_path.as_bytes()[1] == b':'
            && (import_path.as_bytes()[2] == b'/' || import_path.as_bytes()[2] == b'\\'));

    let full = if is_absolute {
        PathBuf::from(import_path)
    } else {
        base_dir.join(import_path)
    };

    let full_em = if is_absolute {
        PathBuf::from(format!("{}.em", import_path))
    } else {
        base_dir.join(format!("{}.em", import_path))
    };

    (full, full_em)
}

/// Resolve an import path relative to a base directory.
/// Handles absolute (Unix `/`, Windows `C:\`) and relative paths.
/// Tries the exact path first, then falls back to `path.em`.
pub fn resolve_import_path(base_dir: &Path, import_path: &str) -> Option<PathBuf> {
    let (full, full_em) = build_import_candidates(base_dir, import_path);
    if full.exists() {
        return Some(full);
    }
    if full_em.exists() {
        return Some(full_em);
    }
    None
}

/// Bundle an entry file, recursively inlining all imports.
pub fn bundle(entry_path: &Path, options: &BundleOptions) -> Result<BundleResult> {
    let mut parser = EnmaParser::new()?;
    let mut stack = HashSet::new();
    let mut visited = HashSet::new();
    bundle_file(entry_path, options, &mut parser, &mut stack, &mut visited)
}

fn bundle_file(
    file_path: &Path,
    options: &BundleOptions,
    parser: &mut EnmaParser,
    stack: &mut HashSet<PathBuf>,
    visited: &mut HashSet<PathBuf>,
) -> Result<BundleResult> {
    // Cycle detection: file is currently on the call stack
    if stack.contains(file_path) {
        let warning = format!(
            "// WARNING: import loop detected for \"{}\"",
            file_path.display()
        );
        return Ok(BundleResult {
            source: warning.clone(),
            warnings: vec![warning],
        });
    }

    let canonical = std::fs::canonicalize(file_path).unwrap_or_else(|_| file_path.to_path_buf());

    // Diamond dedup: file was already fully processed via another import path
    if visited.contains(&canonical) {
        return Ok(BundleResult {
            source: String::new(),
            warnings: Vec::new(),
        });
    }

    stack.insert(file_path.to_path_buf());
    visited.insert(canonical);

    let source = std::fs::read_to_string(file_path)?;

    let processed = if options.strip_comments {
        strip_comments(&source)
    } else {
        source.clone()
    };

    let tree = parser
        .parse(processed.as_bytes())
        .ok_or_else(|| anyhow::anyhow!("Failed to parse {}", file_path.display()))?;

    let root = tree.root_node();
    let imports = collect_imports(root, &processed);

    let mut result = BundleResult {
        source: processed.clone(),
        warnings: Vec::new(),
    };

    let mut replacements: Vec<(usize, usize, String)> = Vec::new();

    for (start, end, import_path) in &imports {
        let clean_path = import_path.trim_matches('"');
        let base_dir = file_path.parent().unwrap_or(Path::new("."));
        let resolved = resolve_import_path(base_dir, clean_path);

        let replacement = if let Some(resolved_path) = resolved {
            let sub = bundle_file(&resolved_path, options, parser, stack, visited)?;
            result.warnings.extend(sub.warnings);

            let file_name = resolved_path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or(clean_path);
            if sub.source.is_empty() {
                String::new()
            } else {
                format!("// {}\n{}", file_name, sub.source)
            }
        } else {
            let warning = format!(
                "// WARNING: could not resolve import \"{}\"",
                clean_path
            );
            result.warnings.push(warning.clone());
            warning
        };

        replacements.push((*start, *end, replacement));
    }

    // Apply replacements in reverse byte order to preserve offsets
    replacements.sort_by_key(|(start, _, _)| std::cmp::Reverse(*start));

    let mut bundled = processed;
    for (start, end, replacement) in &replacements {
        bundled.replace_range(*start..*end, replacement);
    }

    result.source = bundled;
    stack.remove(file_path);

    Ok(result)
}

fn collect_imports(node: Node, source: &str) -> Vec<(usize, usize, String)> {
    let mut imports = Vec::new();

    if node.kind() == "import_statement" {
        if let Some(path_node) = node.child_by_field_name("path") {
            let path = &source[path_node.start_byte()..path_node.end_byte()];
            imports.push((node.start_byte(), node.end_byte(), path.to_string()));
        }
    }

    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        imports.extend(collect_imports(child, source));
    }

    imports
}

// ── Comment stripping ──────────────────────────────────────────

pub fn strip_comments(source: &str) -> String {
    let no_blocks = remove_block_comments(source);
    remove_line_comments(&no_blocks)
}

/// Remove `/* ... */` block comments, tracking string state to avoid
/// matching inside string literals.
fn remove_block_comments(source: &str) -> String {
    let mut out = String::with_capacity(source.len());
    let chars: Vec<char> = source.chars().collect();
    let mut i = 0;
    let mut in_string = false;
    let mut string_char = '"';

    while i < chars.len() {
        if !in_string && (chars[i] == '"' || chars[i] == '\'') {
            in_string = true;
            string_char = chars[i];
            out.push(chars[i]);
            i += 1;
            continue;
        }

        if in_string {
            if chars[i] == '\\' && i + 1 < chars.len() {
                out.push(chars[i]);
                out.push(chars[i + 1]);
                i += 2;
                continue;
            }
            if chars[i] == string_char {
                in_string = false;
            }
            out.push(chars[i]);
            i += 1;
            continue;
        }

        if chars[i] == '/' && i + 1 < chars.len() && chars[i + 1] == '*' {
            i += 2;
            while i < chars.len() {
                if chars[i] == '*' && i + 1 < chars.len() && chars[i + 1] == '/' {
                    i += 2;
                    break;
                }
                i += 1;
            }
            continue;
        }

        out.push(chars[i]);
        i += 1;
    }

    out
}

/// Remove `//` line comments.
/// - Full-line comments (line is only whitespace + `//`): remove entire line
/// - Inline comments (code then `//`): remove from `//` to end, trim trailing whitespace
fn remove_line_comments(source: &str) -> String {
    let mut out = String::with_capacity(source.len());

    for line in source.lines() {
        let trimmed = line.trim_start();
        if trimmed.starts_with("//") {
            continue;
        }

        if let Some(comment_start) = find_comment_start(line) {
            let before = line[..comment_start].trim_end();
            if !before.is_empty() {
                out.push_str(before);
                out.push('\n');
            }
        } else {
            out.push_str(line);
            out.push('\n');
        }
    }

    out
}

/// Find the byte index of a `//` that is not inside a string literal.
fn find_comment_start(line: &str) -> Option<usize> {
    let chars: Vec<char> = line.chars().collect();
    let mut in_string = false;
    let mut string_char = '"';
    let mut i = 0;

    while i < chars.len() {
        let c = chars[i];

        if !in_string && (c == '"' || c == '\'') {
            in_string = true;
            string_char = c;
            i += 1;
            continue;
        }

        if in_string {
            if c == '\\' && i + 1 < chars.len() {
                i += 2;
                continue;
            }
            if c == string_char {
                in_string = false;
            }
            i += 1;
            continue;
        }

        if c == '/' && i + 1 < chars.len() && chars[i + 1] == '/' {
            return Some(i);
        }

        i += 1;
    }

    None
}

// ── Tests ──────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // ── Comment stripping ──

    #[test]
    fn test_strip_full_line_comment() {
        let src = "int32 x = 5;\n// this is a comment\nint32 y = 10;\n";
        let result = strip_comments(src);
        assert_eq!(result, "int32 x = 5;\nint32 y = 10;\n");
    }

    #[test]
    fn test_strip_indented_line_comment() {
        let src = "int32 x = 5;\n\t// indented comment\nint32 y = 10;\n";
        let result = strip_comments(src);
        assert_eq!(result, "int32 x = 5;\nint32 y = 10;\n");
    }

    #[test]
    fn test_strip_block_comment() {
        let src = "int32 x /* inline block */ = 5;\n";
        let result = strip_comments(src);
        assert_eq!(result, "int32 x  = 5;\n");
    }

    #[test]
    fn test_strip_multiline_block_comment() {
        let src = "int32 x = 1;\n/* multi\n   line\n   comment */\nint32 y = 2;\n";
        let result = strip_comments(src);
        assert_eq!(result, "int32 x = 1;\n\nint32 y = 2;\n");
    }

    #[test]
    fn test_strip_inline_comment() {
        let src = "int32 x = 5; // inline comment\nint32 y = 10;\n";
        let result = strip_comments(src);
        assert_eq!(result, "int32 x = 5;\nint32 y = 10;\n");
    }

    #[test]
    fn test_strip_does_not_touch_strings() {
        let src = "string url = \"http://example.com\";\n// real comment\n";
        let result = strip_comments(src);
        assert_eq!(result, "string url = \"http://example.com\";\n");
    }

    #[test]
    fn test_strip_does_not_touch_strings_with_block_comment_like() {
        let src = "string s = \"/* not a comment */\";\nint32 x = 5;\n";
        let result = strip_comments(src);
        assert_eq!(result, "string s = \"/* not a comment */\";\nint32 x = 5;\n");
    }

    #[test]
    fn test_strip_preserves_filename_markers() {
        let src = "// math.em\nint32 add(int32 a, int32 b) { return a + b; }\n";
        let result = strip_comments(src);
        assert_eq!(result, "int32 add(int32 a, int32 b) { return a + b; }\n");
    }

    // ── Path resolution ──

    // ── Path building (pure, no filesystem) ──

    #[test]
    fn test_build_relative_path() {
        let base = Path::new("/project/src");
        let (full, full_em) = build_import_candidates(base, "lib/math.em");
        assert_eq!(full, PathBuf::from("/project/src/lib/math.em"));
        assert_eq!(full_em, PathBuf::from("/project/src/lib/math.em.em"));
    }

    #[test]
    fn test_build_absolute_unix_path() {
        let base = Path::new("/project/src");
        let (full, full_em) = build_import_candidates(base, "/usr/lib/enma/core.em");
        assert_eq!(full, PathBuf::from("/usr/lib/enma/core.em"));
        assert_eq!(full_em, PathBuf::from("/usr/lib/enma/core.em.em"));
    }

    #[test]
    fn test_build_absolute_windows_path() {
        let base = Path::new("C:\\project\\src");
        let (full, full_em) = build_import_candidates(base, "D:\\libs\\math.em");
        assert_eq!(full, PathBuf::from("D:\\libs\\math.em"));
        assert_eq!(full_em, PathBuf::from("D:\\libs\\math.em.em"));
    }

    #[test]
    fn test_build_appends_em_extension() {
        let base = Path::new("/project/src");
        let (full, full_em) = build_import_candidates(base, "lib/math");
        assert_eq!(full, PathBuf::from("/project/src/lib/math"));
        assert_eq!(full_em, PathBuf::from("/project/src/lib/math.em"));
    }

    // ── Bundling integration tests ──

    fn fixtures_dir() -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap()
            .join("test")
            .join("bundle")
    }

    fn examples_dir() -> PathBuf {
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .unwrap()
            .join("examples")
            .join("import-test")
    }

    #[test]
    fn test_bundle_no_imports() {
        let math = fixtures_dir().join("lib").join("math.em");
        let result = bundle(&math, &BundleOptions::default()).unwrap();
        assert!(result.warnings.is_empty());
        assert!(result.source.contains("int32 add"));
        assert!(result.source.contains("int32 mul"));
        assert!(!result.source.contains("import"));
    }

    #[test]
    fn test_bundle_single_import() {
        let main = examples_dir().join("main.em");
        let result = bundle(&main, &BundleOptions::default()).unwrap();
        assert!(!result.source.contains("import \"lib/lib.em\""));
        assert!(result.source.contains("// lib.em"));
        assert!(result.source.contains("struct Cell"));
        assert!(result.source.contains("int32 main"));
    }

    #[test]
    fn test_bundle_nested_imports() {
        let entry = fixtures_dir().join("entry.em");
        let result = bundle(&entry, &BundleOptions::default()).unwrap();
        assert!(!result.source.contains("import \"lib/math.em\""));
        assert!(!result.source.contains("import \"lib/strings.em\""));
        assert!(result.source.contains("// math.em"));
        assert!(result.source.contains("// strings.em"));
        assert!(result.source.contains("int32 add"));
        assert!(result.source.contains("int32 strlen"));
        assert!(result.source.contains("int32 main"));
    }

    #[test]
    fn test_bundle_with_strip_comments() {
        let entry = fixtures_dir().join("entry.em");
        let opts = BundleOptions {
            strip_comments: true,
        };
        let result = bundle(&entry, &opts).unwrap();
        assert!(!result.source.contains("// strings.em — string utilities"));
        assert!(!result.source.contains("// use mul from math.em"));
        assert!(result.source.contains("// math.em"));
        assert!(result.source.contains("// strings.em"));
    }

    #[test]
    fn test_bundle_circular_import() {
        let tmp = std::env::temp_dir().join("enma_bundle_test");
        let _ = std::fs::create_dir_all(&tmp);
        let a_path = tmp.join("a.em");
        let b_path = tmp.join("b.em");
        std::fs::write(&a_path, "import \"b.em\";\nint32 x = 1;\n").unwrap();
        std::fs::write(&b_path, "import \"a.em\";\nint32 y = 2;\n").unwrap();

        let result = bundle(&a_path, &BundleOptions::default()).unwrap();
        assert!(result.warnings.iter().any(|w| w.contains("import loop")));
        assert!(result.source.contains("WARNING: import loop"));
        assert!(result.source.contains("int32 x = 1"));
        assert!(result.source.contains("int32 y = 2"));

        let _ = std::fs::remove_dir_all(&tmp);
    }
}
