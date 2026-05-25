// tree-sitter-enma — grammar.js
// Enma scripting language (.em). Flat token-based grammar for keyword extraction
// and syntax highlighting. Structural analysis is done by the LSP server.
//
// Pattern: NO external scanner, ALL keywords/types/operators listed flat in
// _expr_part. This ensures tree-sitter extracts every keyword reliably.

module.exports = grammar({
  name: "enma",

  extras: ($) => [/\s/, $.comment],

  word: ($) => $.identifier,

  rules: {
    // === Top level ===
    source_file: ($) => repeat($._item),

    _item: ($) => choice(
      $.preprocessor,
      $.block,
      $.expression_statement,
    ),

    // === Preprocessor (inline, no external scanner) ===
    preprocessor: ($) => seq(
      "#",
      field("directive", $.identifier),
      optional(field("arg", $._rest_of_line)),
    ),

    _rest_of_line: ($) => /[^\n]*/,

    // === Comment (inline regex, no external scanner) ===
    comment: ($) => token(choice(
      seq("//", /.*/),
      seq("/*", /[^*]*\*+([^/*][^*]*\*+)*/, "/"),
    )),

    // === Literals ===
    string: ($) => seq(
      '"',
      repeat(choice(token.immediate(/[^"\\]+/), $.escape)),
      '"',
    ),

    f_string: ($) => seq(
      "f", '"',
      repeat(choice(
        token.immediate(/[^"\\{]+/),
        $.escape,
        $.interpolation,
      )),
      '"',
    ),

    interpolation: ($) => seq("{", repeat($._expr_part), "}"),

    char_literal: ($) => seq(
      "'",
      choice($.escape, /[^'\\]/),
      "'",
    ),

    escape: ($) => token.immediate(
      /\\(x[0-9A-Fa-f]{1,4}|u[0-9A-Fa-f]{1,8}|.)/,
    ),

    number: ($) => token(choice(
      /0[xX][0-9a-fA-F_]+/,
      /0[bB][01_]+/,
      /(\d+\.\d*|\.\d+)([eE][+-]?\d+)?[fF]?/,
      /\d[\d'_]*/,
    )),

    // === Identifiers ===
    identifier: ($) => /[A-Za-z_][A-Za-z0-9_]*/,

    // === Core flat expression ===
    expression_statement: ($) => seq(optional($._expr), ";"),

    _expr: ($) => repeat1($._expr_part),

    _expr_part: ($) => choice(
      // Literals
      $.identifier, $.number, $.string, $.f_string, $.char_literal,
      // Grouping
      $.parenthesized, $.bracketed,
      // Assignment operators
      "=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<=", ">>=",
      // Logical
      "||", "&&",
      // Comparison + three-way
      "==", "!=", "<", ">", "<=", ">=", "<=>",
      // Bitwise
      "|", "^", "&",
      // Arithmetic
      "+", "-", "*", "/", "%",
      // Shift
      "<<", ">>",
      // Member access
      ".", "->", "::",
      // Increment / decrement
      "++", "--",
      // Unary
      "!", "~",
      // Ternary
      "?", ":",
      // Other
      ",", "...", "@",
      // Object lifetime
      "new", "delete",
      // Built-in intrinsics
      "sizeof", "offsetof", "decltype",
      // Cast operators
      "cast", "static_cast", "reinterpret_cast", "const_cast", "move",
      // Literals
      "true", "false", "null",
      // this
      "this",
      // ---- Control flow ----
      "if", "else", "for", "while", "do",
      "switch", "case", "default",
      "break", "continue", "return",
      "try", "catch", "throw",
      "defer", "yield", "goto",
      "match",
      // ---- Module system ----
      "import", "using", "namespace",
      // ---- OOP ----
      "class", "struct", "interface", "mixin", "enum",
      "virtual", "override", "final", "property",
      "operator", "friend", "explicit",
      // ---- Templates ----
      "template", "typename",
      // ---- Declarations ----
      "const", "constexpr", "auto", "nullable",
      "extern", "out", "delegate", "coroutine",
      "typedef", "static_assert",
      // ---- Access ----
      "private", "public",
      // ---- Annotations ----
      "inline", "noinline", "noopt", "noescape",
      "packed", "reflect", "serialize", "export",
      "dll",
      // ---- Asm intrinsics ----
      "__asm_rdtsc", "__asm_pause", "__asm_mfence", "__asm_nop",
      // ---- Variadic ----
      "__va_count", "__va_arg",
      // ---- Primitive types ----
      "bool", "char", "wchar", "wchar_t",
      "int8", "int16", "int32", "int64",
      "uint8", "uint16", "uint32", "uint64",
      "aint8", "aint16", "aint32", "aint64",
      "float32", "float64",
      "string", "wstring", "void",
      // ---- Addon / SDK types ----
      "vec2", "vec3", "vec4", "quat", "mat4",
      "map", "hash_set", "sorted_map",
      "variant", "coroutine_t",
      "atomic_int32", "atomic_int64",
      "mutex", "cond_var", "lock_guard",
      "file_t", "regex", "json_value",
      "proc_t", "cpu_t", "ws_t", "udp_t",
      "http_response_t", "sound_t",
      // ---- Annotation brackets ----
      $.annotation,
    ),

    parenthesized: ($) => seq("(", repeat($._expr_part), ")"),
    bracketed: ($) => seq("[", repeat($._expr_part), "]"),
    block: ($) => seq("{", repeat($._item), "}"),

    annotation: ($) => seq(
      "[[",
      field("name", $.identifier),
      optional(seq("(", repeat($._expr_part), ")")),
      "]]",
    ),
  },
});
