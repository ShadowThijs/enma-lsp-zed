// tree-sitter-enma — grammar.js
// Enma is a C/C++-like JIT-compiled scripting language (x64).
// File extension: .em
//
// Design follows tree-sitter-cpp's pattern:
//   - _type_identifier aliases identifier for AST labeling (inlined away)
//   - template_argument_list uses prec.dynamic to prefer types over expressions
//   - GLR conflicts resolve identifier-as-type vs identifier-as-expression

module.exports = grammar({
  name: "enma",

  externals: ($) => [
    $._preprocessor_directive,
    $._interpolation_open,
    $._interpolation_close,
    $.comment,
  ],

  extras: ($) => [
    $.comment,
    $._preprocessor_directive,
    /[\s\f﻿⁠​]|\r?\n/,
  ],

  inline: ($) => [
    $._type_identifier,
    $._field_identifier,
  ],

  conflicts: ($) => [
    // identifier as type vs expression (tree-sitter-cpp GLR pattern)
    [$._type_specifier, $._expression],
    [$.template_type, $._expression],
    [$.template_type, $._type_specifier],
    // additional structural conflicts
    [$.new_expression],
    [$.brace_init_expression, $.compound_statement],
  ],

  word: ($) => $.identifier,

  rules: {
    // === Source file ===
    source_file: ($) => repeat($._declaration),

    _declaration: ($) => choice(
      $.function_definition,
      $.struct_definition,
      $.class_definition,
      $.coroutine_definition,
      $.enum_definition,
      $.global_variable_declaration,
      $.import_declaration,
      $.namespace_definition,
      $.template_declaration,
      $.typedef_declaration,
      $.using_declaration,
      $.static_assert_declaration,
    ),

    // === Preprocessor (scanner-driven) ===
    preproc_arg: ($) => /[^\n]+/,
    preproc_identifier: ($) => $.identifier,
    system_lib_string: ($) => seq("<", /[^>\n]+/, ">"),

    // === Literals ===
    string_literal: ($) => choice($._normal_string, $._interpolated_string),

    _normal_string: ($) => token(seq(
      '"',
      repeat(choice(
        /[^"\\\n]+/,
        seq("\\", choice(/[ntr0\\'"]/, seq("x", /[0-9a-fA-F]{1,2}/), /./)),
      )),
      '"',
    )),

    _interpolated_string: ($) => seq(
      'f"',
      repeat(choice(
        /[^"{}\\\n]+/,
        seq("\\", choice(/[ntr0\\'"]/, seq("x", /[0-9a-fA-F]{1,2}/), /./)),
        $._interpolation_open, $._expression, $._interpolation_close,
      )),
      '"',
    ),

    number_literal: ($) => {
      const hex = /0[xX][0-9a-fA-F]+(_[0-9a-fA-F]+)*/;
      const bin = /0[bB][01]+(_[01]+)*/;
      const dec = /[0-9]+(_[0-9]+)*/;
      const exp = /[eE][+-]?[0-9]+(_[0-9]+)*/;
      const fs = /[fF]/;
      const udl = /_[a-zA-Z_][a-zA-Z0-9_]*/;
      return token(choice(
        seq(hex, optional(udl)),
        seq(bin, optional(udl)),
        seq(dec, ".", dec, exp, optional(fs), optional(udl)),
        seq(dec, exp, optional(fs), optional(udl)),
        seq(dec, ".", dec, optional(fs), optional(udl)),
        seq(dec, udl),
        seq(dec, optional(choice(
          seq(".", dec, optional(exp), optional(fs)),
          seq(exp, optional(fs)), seq(fs),
        ))),
      ));
    },

    boolean_literal: ($) => choice("true", "false"),
    null_literal: ($) => "null",

    // === Identifiers (following tree-sitter-cpp pattern) ===
    identifier: ($) => /[_a-zA-Z][_a-zA-Z0-9]*/,

    _type_identifier: ($) => alias($.identifier, $.type_identifier),
    _field_identifier: ($) => alias($.identifier, $.field_identifier),

    // === Primitive types (separate token() rules for keyword extraction) ===
    _t_bool: ($) => token("bool"),
    _t_char: ($) => token("char"),
    _t_wchar: ($) => token("wchar"),
    _t_wchar_t: ($) => token("wchar_t"),
    _t_int8: ($) => token("int8"),
    _t_int16: ($) => token("int16"),
    _t_int32: ($) => token("int32"),
    _t_int64: ($) => token("int64"),
    _t_uint8: ($) => token("uint8"),
    _t_uint16: ($) => token("uint16"),
    _t_uint32: ($) => token("uint32"),
    _t_uint64: ($) => token("uint64"),
    _t_aint8: ($) => token("aint8"),
    _t_aint16: ($) => token("aint16"),
    _t_aint32: ($) => token("aint32"),
    _t_aint64: ($) => token("aint64"),
    _t_float32: ($) => token("float32"),
    _t_float64: ($) => token("float64"),
    _t_string: ($) => token("string"),
    _t_wstring: ($) => token("wstring"),
    _t_void: ($) => token("void"),

    primitive_type: ($) => choice(
      $._t_bool, $._t_char, $._t_wchar, $._t_wchar_t,
      $._t_int8, $._t_int16, $._t_int32, $._t_int64,
      $._t_uint8, $._t_uint16, $._t_uint32, $._t_uint64,
      $._t_aint8, $._t_aint16, $._t_aint32, $._t_aint64,
      $._t_float32, $._t_float64,
      $._t_string, $._t_wstring, $._t_void,
    ),

    // === Type specifiers ===
    _type_specifier: ($) => choice(
      $.primitive_type,
      $.qualified_type,
      $.template_type,
      $.array_type,
      $.map_type,
      $.pointer_type,
      // catch-all: any identifier can be a type (GLR-disambiguated)
      $._type_identifier,
    ),

    qualified_type: ($) => seq(
      field("scope", choice($._type_identifier, $.qualified_type, $.primitive_type)),
      "::",
      field("name", $._type_identifier),
    ),

    template_argument_list: ($) => seq(
      "<",
      commaSep(choice(
        prec.dynamic(3, $._type_specifier), // prefer type interpretation
        prec.dynamic(1, $._expression),      // fallback: expression/comparison
      )),
      alias(token(prec(1, ">")), ">"),
    ),

    template_type: ($) => seq(
      field("name", choice($._type_identifier, $.primitive_type)),
      field("arguments", $.template_argument_list),
    ),

    array_type: ($) => prec.left(seq(field("element", $._type_specifier), "[]")),

    map_type: ($) => seq(
      "map", "<",
      field("key", $._type_specifier), ",",
      field("value", $._type_specifier),
      ">",
    ),

    pointer_type: ($) => seq(field("element", $._type_specifier), "*"),

    // === Expressions ===
    _expression: ($) => choice(
      $.assignment_expression,
      $.ternary_expression,
      $.binary_expression,
      $.unary_expression,
      $.update_expression,
      $.cast_expression,
      $.call_expression,
      $.subscript_expression,
      $.field_expression,
      $.pointer_expression,
      $.scope_expression,
      $.new_expression,
      $.delete_expression,
      $.sizeof_expression,
      $.lambda_expression,
      $.match_expression,
      $.brace_init_expression,
      $.string_literal,
      $.number_literal,
      $.boolean_literal,
      $.null_literal,
      $.identifier,
      $.this_expression,
      $.parenthesized_expression,
    ),

    this_expression: ($) => "this",
    parenthesized_expression: ($) => seq("(", $._expression, ")"),

    assignment_expression: ($) => prec.right(1, seq(
      field("left", $._expression),
      field("operator", choice(
        "=", "+=", "-=", "*=", "/=", "%=",
        "&=", "|=", "^=", "<<=", ">>=",
      )),
      field("right", $._expression),
    )),

    ternary_expression: ($) => prec.right(2, seq(
      field("condition", $._expression), "?",
      field("consequence", $._expression), ":",
      field("alternative", $._expression),
    )),

    binary_expression: ($) => {
      const table = [
        [3, "||"], [4, "&&"], [5, "|"], [6, "^"], [7, "&"],
        [8, choice("==", "!=")],
        [9, choice("<", "<=", ">", ">=")],
        [10, choice("<<", ">>")],
        [11, choice("+", "-")],
        [12, choice("*", "/", "%")],
      ];
      return choice(...table.map(([p, op]) =>
        prec.left(p, seq(
          field("left", $._expression),
          field("operator", op),
          field("right", $._expression),
        ))
      ));
    },

    unary_expression: ($) => prec(13, seq(
      field("operator", choice("-", "!", "~", "+", "*", "&")),
      field("operand", $._expression),
    )),

    update_expression: ($) => choice(
      prec(13, seq(field("operator", choice("++", "--")), field("operand", $._expression))),
      prec(14, seq(field("operand", $._expression), field("operator", choice("++", "--")))),
    ),

    cast_expression: ($) => prec(15, seq(
      field("keyword", choice("cast", "static_cast", "reinterpret_cast", "const_cast")),
      "<", field("type", $._type_specifier), ">",
      "(", field("value", $._expression), ")",
    )),

    call_expression: ($) => prec(14, seq(
      field("function", $._expression),
      "(", optional(commaSep1($._expression)), ")",
    )),

    subscript_expression: ($) => prec(14, seq(
      field("object", $._expression),
      "[", field("index", $._expression), "]",
    )),

    field_expression: ($) => prec(14, seq(
      field("object", $._expression), ".",
      field("field", $._field_identifier),
    )),

    pointer_expression: ($) => prec(14, seq(
      field("object", $._expression), "->",
      field("field", $._field_identifier),
    )),

    scope_expression: ($) => prec(14, seq(
      field("scope", $.identifier),
      "::",
      field("name", $.identifier),
    )),

    new_expression: ($) => prec(13, seq(
      "new",
      field("type", $._type_specifier),
      optional(choice(
        seq("(", optional(commaSep1($._expression)), ")"),
        seq("[", $._expression, "]"),
        seq("[", $._expression, "]", "(", optional(commaSep1($._expression)), ")"),
      )),
    )),

    delete_expression: ($) => prec(13, seq(
      choice("delete", "delete[]"),
      field("value", $._expression),
    )),

    sizeof_expression: ($) => prec(13, seq(
      "sizeof", "(",
      field("type", $._type_specifier),
      ")",
    )),

    lambda_expression: ($) => seq(
      optional(seq(
        "[", optional(commaSep1(choice($.identifier, seq("&", $.identifier)))), "]"
      )),
      "(", optional(commaSep1($.parameter_declaration)), ")",
      optional(seq("->", $._type_specifier)),
      $.compound_statement,
    ),

    match_expression: ($) => seq(
      "match", "(", $._expression, ")", "{",
      repeat(seq(
        optional("case"),
        field("pattern", choice($._expression, "_")),
        "=>",
        field("body", choice($._expression, $.compound_statement)),
        optional(","),
      )),
      "}",
    ),

    brace_init_expression: ($) => seq(
      "{", optional(commaSep1($._expression)), "}",
    ),

    // === Statements ===
    _statement: ($) => choice(
      $.compound_statement,
      $.expression_statement,
      $.if_statement,
      $.for_statement,
      $.for_each_statement,
      $.while_statement,
      $.do_while_statement,
      $.switch_statement,
      $.defer_statement,
      $.goto_statement,
      $.labeled_statement,
      $.break_statement,
      $.continue_statement,
      $.return_statement,
      $.throw_statement,
      $.try_statement,
      $.yield_statement,
    ),

    compound_statement: ($) => seq("{", repeat($._statement), "}"),

    expression_statement: ($) => seq(optional($._expression), ";"),

    if_statement: ($) => prec.right(seq(
      "if", "(", $._expression, ")",
      field("consequence", $._statement),
      optional(seq("else", field("alternative", $._statement))),
    )),

    for_statement: ($) => seq(
      "for", "(",
      field("initializer", optional(choice($._expression, $.local_variable_declaration))), ";",
      field("condition", optional($._expression)), ";",
      field("increment", optional($._expression)),
      ")",
      field("body", $._statement),
    ),

    for_each_statement: ($) => seq(
      "for", "(",
      field("type", $._type_specifier),
      field("variable", $.identifier),
      ":",
      field("container", $._expression),
      ")",
      field("body", $._statement),
    ),

    while_statement: ($) => seq("while", "(", $._expression, ")", $._statement),
    do_while_statement: ($) => seq("do", $._statement, "while", "(", $._expression, ")", ";"),

    switch_statement: ($) => seq(
      "switch", "(", $._expression, ")", "{",
      repeat(choice(
        seq("case", $._expression, ":", repeat($._statement)),
        seq("default", ":", repeat($._statement)),
      )),
      "}",
    ),

    defer_statement: ($) => seq("defer", choice($.compound_statement, seq($._expression, ";"))),
    goto_statement: ($) => seq("goto", $.identifier, ";"),
    labeled_statement: ($) => seq($.identifier, ":", $._statement),
    break_statement: ($) => seq("break", ";"),
    continue_statement: ($) => seq("continue", ";"),
    return_statement: ($) => seq("return", optional($._expression), ";"),
    throw_statement: ($) => seq("throw", optional($._expression), ";"),
    yield_statement: ($) => seq("yield", $._expression, ";"),

    try_statement: ($) => seq(
      "try", $.compound_statement,
      repeat(seq(
        "catch", "(",
        field("type", $._type_specifier),
        field("parameter", $.identifier),
        ")",
        $.compound_statement,
      )),
    ),

    local_variable_declaration: ($) => seq(
      optional(choice("const", "constexpr", "nullable")),
      field("type", $._type_specifier),
      commaSep1($.field_declarator),
    ),

    // === Functions ===
    function_definition: ($) => seq(
      field("return_type", $._type_specifier),
      field("name", $.identifier),
      "(", optional(commaSep1($.parameter_declaration)), ")",
      field("body", $.compound_statement),
    ),

    parameter_declaration: ($) => seq(
      optional(choice("const", "out")),
      field("type", $._type_specifier),
      optional("&"),
      field("name", $.identifier),
      optional(seq("=", field("default_value", $._expression))),
    ),

    // === Struct ===
    struct_definition: ($) => seq(
      optional($.annotation_list),
      "struct",
      field("name", $._type_identifier),
      optional(seq(":", commaSep1(choice($._type_identifier, $.qualified_type)))),
      "{", repeat(choice(
        $.field_declaration,
        $.bitfield_declaration,
        $.method_definition,
        $.constructor_definition,
        $.destructor_definition,
        $.property_declaration,
      )), "}",
    ),

    field_declaration: ($) => seq(
      optional($.annotation_list),
      optional("const"),
      field("type", $._type_specifier),
      commaSep1(seq(
        field("name", $._field_identifier),
        optional(seq("=", $._expression)),
      )),
      ";",
    ),

    bitfield_declaration: ($) => seq(
      field("type", $._type_specifier),
      field("name", $._field_identifier), ":",
      field("width", $.number_literal), ";",
    ),

    method_definition: ($) => seq(
      optional($.annotation_list),
      optional(choice("virtual", "override")),
      field("return_type", $._type_specifier),
      field("name", $._field_identifier),
      "(", optional(commaSep1($.parameter_declaration)), ")",
      optional("const"),
      optional("override"),
      field("body", $.compound_statement),
    ),

    constructor_definition: ($) => seq(
      field("name", $.identifier),
      "(", optional(commaSep1($.parameter_declaration)), ")",
      optional(seq(
        ":",
        commaSep1(seq(
          $.identifier,
          "(",
          optional(commaSep1($._expression)),
          ")",
        )),
      )),
      $.compound_statement,
    ),

    destructor_definition: ($) => seq(
      "~", field("name", $.identifier), "(", ")", $.compound_statement,
    ),

    property_declaration: ($) => seq(
      "property", $._type_specifier, field("name", $._field_identifier), "{",
      optional(seq("get", $.compound_statement)),
      optional(seq("set", $.compound_statement)),
      "}",
    ),

    // === Class ===
    class_definition: ($) => seq(
      optional($.annotation_list),
      "class",
      field("name", $._type_identifier),
      optional(seq(":", commaSep1(choice($._type_identifier, $.qualified_type)))),
      "{", repeat(choice(
        $.field_declaration,
        $.bitfield_declaration,
        $.method_definition,
        $.constructor_definition,
        $.destructor_definition,
        $.property_declaration,
      )), "}",
    ),

    // === Enum ===
    enum_definition: ($) => seq(
      "enum", optional(choice("class", "struct")),
      field("name", $._type_identifier),
      "{",
      commaSep1(seq($.identifier, optional(seq("=", $._expression)))),
      "}",
    ),

    // === Template ===
    template_declaration: ($) => seq(
      "template", "<",
      commaSep1(seq("typename", field("name", $._type_identifier))),
      ">",
      field("body", choice(
        $.function_definition,
        $.struct_definition,
        $.class_definition,
      )),
    ),

    // === Coroutine ===
    coroutine_definition: ($) => seq(
      "coroutine",
      field("return_type", $._type_specifier),
      field("name", $.identifier),
      "(", optional(commaSep1($.parameter_declaration)), ")",
      field("body", $.compound_statement),
    ),

    // === Other top-level ===
    global_variable_declaration: ($) => seq(
      optional($.annotation_list),
      optional(choice("const", "constexpr", "nullable")),
      field("type", $._type_specifier),
      commaSep1(seq(
        field("name", $.identifier),
        optional(seq("=", field("value", $._expression))),
      )),
      ";",
    ),

    import_declaration: ($) => seq(
      "import",
      field("path", choice($.string_literal, $.identifier)),
      optional(seq("as", field("alias", $.identifier))),
      ";",
    ),

    namespace_definition: ($) => seq(
      "namespace", field("name", $.identifier),
      "{", repeat($._declaration), "}",
    ),

    typedef_declaration: ($) => seq(
      "typedef", $._type_specifier, field("alias", $._type_identifier), ";",
    ),

    using_declaration: ($) => seq(
      "using", field("alias", $._type_identifier), "=", $._type_specifier, ";",
    ),

    static_assert_declaration: ($) => seq(
      "static_assert", "(",
      field("condition", $._expression),
      optional(seq(",", field("message", $.string_literal))),
      ")", ";",
    ),

    // === Annotations ===
    annotation_list: ($) => repeat1($.annotation),

    annotation: ($) => seq(
      "[[", field("name", $.identifier),
      optional(seq("(", commaSep1($._expression), ")")),
      "]]",
    ),

    // === Field declarator ===
    field_declarator: ($) => seq(
      field("name", $.identifier),
      optional(seq("=", field("value", $._expression))),
    ),
  },
});

function commaSep(rule) {
  return seq(rule, repeat(seq(",", rule)), optional(","));
}

function commaSep1(rule) {
  return seq(rule, repeat(seq(",", rule)), optional(","));
}
