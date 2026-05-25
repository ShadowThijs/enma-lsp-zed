// Enma structured grammar for tree-sitter
// Covers: functions, classes, structs, enums, interfaces, namespaces,
// templates, control flow, expressions with full operator precedence,
// types (primitives, pointers, references, arrays, generics, nullable),
// lambdas, match, imports, preprocessor, annotations, and more.

module.exports = grammar({
  name: 'enma',

  extras: $ => [/\s/, $.comment],

  word: $ => $.identifier,

  conflicts: $ => [
    [$._primary_expression, $._type],
    [$._primary_expression, $.generic_type],
    [$.scope_resolution, $.scope_type],
    [$._cast_expression, $._primary_expression, $._type],
    [$._cast_expression, $._type],
    [$.designated_initializer, $.initializer_list, $.block],
    [$.designated_initializer, $.initializer_list],
    [$._type, $.generic_type],
    [$._postfix_expression],
    [$._unary_expression],
    [$.expression_statement, $.declaration_statement]
  ],

  rules: {
    // =========================================================================
    // TOP LEVEL
    // =========================================================================

    translation_unit: $ => repeat($._definition),

    _definition: $ => choice(
      $.import_statement,
      $.preproc_directive,
      $.function_definition,
      $.function_declaration,
      $.struct_declaration,
      $.class_declaration,
      $.interface_declaration,
      $.mixin_declaration,
      $.enum_declaration,
      $.namespace_definition,
      $.template_declaration,
      $.type_alias,
      $.delegate_declaration,
      $.global_variable_declaration,
      $.static_assert_declaration,
      $.empty_statement,
    ),

    // ---- Import ----
    import_statement: $ => seq('import', field('path', $.string_literal), ';'),

    // ---- Preprocessor ----
    preproc_directive: $ => seq(
      '#',
      field('directive', alias($.preproc_command, $.identifier)),
      optional(field('args', $.preproc_args)),
    ),
    preproc_command: $ => /[a-zA-Z_][a-zA-Z0-9_]*/,
    preproc_args: $ => /[^\n]*/,

    // =========================================================================
    // DECLARATIONS
    // =========================================================================

    // ---- Function Definition ----
    function_definition: $ => seq(
      optional($.annotation),
      optional(choice('constexpr', 'coroutine', 'static', 'inline', 'extern')),
      field('return_type', $._type),
      field('name', $.identifier),
      field('parameters', $.parameter_list),
      optional(choice('const', 'override', 'final', 'virtual')),
      field('body', $.block),
    ),

    // ---- Function Declaration (forward decl, no body) ----
    function_declaration: $ => seq(
      optional($.annotation),
      optional(choice('constexpr', 'coroutine', 'static', 'inline', 'extern')),
      field('return_type', $._type),
      field('name', $.identifier),
      field('parameters', $.parameter_list),
      ';',
    ),

    // ---- Trailing Return Type ----
    trailing_return_type: $ => seq(
      'auto',
      field('name', $.identifier),
      field('parameters', $.parameter_list),
      '->',
      field('return_type', $._type),
      field('body', $.block),
    ),

    // ---- Parameters ----
    parameter_list: $ => seq(
      '(',
      optional(seq(
        commaSep($.parameter_declaration),
        optional(seq(',', '...')),
      )),
      optional(seq(',', '...')),
      ')',
    ),

    parameter_declaration: $ => seq(
      optional('const'),
      optional(field('direction', choice('out', 'inout'))),
      field('type', $._type),
      optional(seq(
        field('name', $.identifier),
        optional(seq('=', field('default_value', $._expression))),
      )),
    ),

    // ---- Struct Declaration ----
    struct_declaration: $ => seq(
      optional($.annotation),
      'struct',
      field('name', $.identifier),
      optional(field('base_classes', $.base_clause)),
      field('body', $.struct_body),
    ),

    struct_body: $ => seq(
      '{',
      repeat(choice(
        $.field_declaration,
        $.constructor_declaration,
        $.destructor_declaration,
        $.method_declaration,
        $.operator_overload,
        $.property_declaration,
        $.access_specifier,
      )),
      '}',
    ),

    base_clause: $ => seq(':', commaSep1($.identifier)),

    // ---- Class Declaration ----
    class_declaration: $ => seq(
      optional($.annotation),
      'class',
      field('name', $.identifier),
      optional(field('base_classes', $.base_clause)),
      field('body', $.class_body),
    ),

    class_body: $ => seq(
      '{',
      repeat(choice(
        $.access_specifier,
        $.field_declaration,
        $.constructor_declaration,
        $.destructor_declaration,
        $.method_declaration,
        $.operator_overload,
        $.property_declaration,
      )),
      '}',
    ),

    // ---- Members ----
    field_declaration: $ => seq(
      optional($.annotation),
      field('type', $._type),
      field('name', $.identifier),
      optional(seq(':', field('bit_width', $._expression))),
      optional(seq('=', field('default_value', $._expression))),
      ';',
    ),

    constructor_declaration: $ => seq(
      field('name', $.identifier),
      field('parameters', $.parameter_list),
      optional(seq(':', field('init_list', $.constructor_init_list))),
      field('body', $.block),
    ),

    constructor_init_list: $ => commaSep1($.init_entry),
    init_entry: $ => seq(field('name', $.identifier), '(', field('value', $._expression), ')'),

    destructor_declaration: $ => seq(
      '~',
      field('name', $.identifier),
      '(', ')',
      field('body', $.block),
    ),

    method_declaration: $ => seq(
      optional(choice('constexpr', 'static', 'inline', 'virtual', 'override', 'final', 'const')),
      field('return_type', $._type),
      field('name', $.identifier),
      field('parameters', $.parameter_list),
      optional(choice('const', 'override', 'final')),
      field('body', $.block),
    ),

    operator_overload: $ => seq(
      field('return_type', $._type),
      'operator',
      field('operator', choice(
        '+', '-', '*', '/', '%', '^', '&', '|', '~', '!',
        '==', '!=', '<', '>', '<=', '>=', '<=>',
        '<<', '>>', '[]', '[]=', '()', '->',
        '++', '--',
        '=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>=',
      )),
      field('parameters', $.parameter_list),
      optional('const'),
      field('body', $.block),
    ),

    property_declaration: $ => seq(
      'property',
      field('type', $._type),
      field('name', $.identifier),
      '{',
      optional($.getter),
      optional($.setter),
      '}',
    ),

    getter: $ => seq('get', field('body', $.block)),
    setter: $ => seq('set', field('body', $.block)),

    access_specifier: $ => seq(choice('private', 'public', 'protected'), ':'),

    // ---- Interface ----
    interface_declaration: $ => seq(
      'interface',
      field('name', $.identifier),
      '{',
      repeat(seq(
        field('return_type', $._type),
        field('name', $.identifier),
        field('parameters', $.parameter_list),
        ';',
      )),
      '}',
    ),

    // ---- Mixin ----
    mixin_declaration: $ => seq(
      'mixin',
      field('return_type', $._type),
      field('struct_name', $.identifier),
      '::',
      field('name', $.identifier),
      field('parameters', $.parameter_list),
      field('body', $.block),
    ),

    // ---- Enum ----
    enum_declaration: $ => seq(
      choice('enum', 'enum class', 'enum struct'),
      field('name', $.identifier),
      '{',
      commaSep(seq(
        field('name', $.identifier),
        optional(seq('=', field('value', $._expression))),
      )),
      optional(','),
      '}',
    ),

    // ---- Namespace ----
    namespace_definition: $ => seq(
      'namespace',
      field('name', $.identifier),
      '{',
      repeat($._definition),
      '}',
    ),

    // ---- Template ----
    template_declaration: $ => seq(
      'template',
      '<',
      commaSep1(seq(
        choice('typename', 'class'),
        field('name', $.identifier),
        optional(seq('=', field('default', $._type))),
      )),
      '>',
      field('body', choice(
        $.function_definition,
        $.function_declaration,
        $.struct_declaration,
        $.class_declaration,
        $.interface_declaration,
        $.type_alias,
      )),
    ),

    // ---- Type Alias ----
    type_alias: $ => seq(
      choice('using', 'typedef'),
      optional(field('alias', $.identifier)),
      optional('='),
      field('type', $._type),
      ';',
    ),

    // ---- Delegate ----
    delegate_declaration: $ => seq(
      'delegate',
      field('return_type', $._type),
      field('name', $.identifier),
      field('parameters', $.parameter_list),
      ';',
    ),

    // ---- Global Variable ----
    global_variable_declaration: $ => seq(
      optional($.annotation),
      optional(field('qualifier', choice('const', 'constexpr', 'static'))),
      field('type', $._type),
      field('name', $.identifier),
      optional(field('array_size', $.array_size_specifier)),
      optional(seq('=', field('value', $._expression))),
      ';',
    ),

    array_size_specifier: $ => seq('[', $._expression, ']'),

    // ---- Static Assert ----
    static_assert_declaration: $ => seq(
      'static_assert',
      '(',
      field('condition', $._expression),
      optional(seq(',', field('message', $.string_literal))),
      ')',
      ';',
    ),

    // ---- Annotation ----
    annotation: $ => seq(
      '[[',
      field('name', $.identifier),
      optional(seq('(', optional($.annotation_args), ')')),
      ']]',
    ),
    annotation_args: $ => commaSep1($._expression),

    // =========================================================================
    // STATEMENTS
    // =========================================================================

    _statement: $ => choice(
      $.expression_statement,
      $.declaration_statement,
      $.block,
      $.if_statement,
      $.while_statement,
      $.do_statement,
      $.for_statement,
      $.for_each_statement,
      $.switch_statement,
      $.try_statement,
      $.throw_statement,
      $.defer_statement,
      $.return_statement,
      $.break_statement,
      $.continue_statement,
      $.goto_statement,
      $.labeled_statement,
      $.block,
      $.empty_statement,
    ),

    expression_statement: $ => seq($._expression, ';'),
    declaration_statement: $ => seq(
      optional(field('qualifier', choice('const', 'constexpr'))),
      field('type', $._local_type),
      field('name', $.identifier),
      optional(seq('=', field('value', $._expression))),
      ';',
    ),

    // Types valid in local variable declarations — excludes bare identifier
    // to avoid ambiguity with assignment expressions
    _local_type: $ => choice(
      $.primitive_type,
      $.pointer_type,
      $.reference_type,
      $.array_type,
      $.nullable_type,
      $.generic_type,
      $.scope_type,
    ),
    empty_statement: $ => ';',

    // ---- Block ----
    block: $ => seq('{', repeat($._statement), '}'),

    // ---- If ----
    if_statement: $ => prec.right(seq(
      'if',
      '(',
      optional(seq(field('init', $._statement), ';')),
      field('condition', $._expression),
      ')',
      field('consequence', $._statement),
      optional(seq('else', field('alternative', $._statement))),
    )),

    // ---- While ----
    while_statement: $ => seq(
      'while', '(', field('condition', $._expression), ')',
      field('body', $._statement),
    ),

    // ---- Do-While ----
    do_statement: $ => seq(
      'do', field('body', $._statement),
      'while', '(', field('condition', $._expression), ')', ';',
    ),

    // ---- For ----
    for_statement: $ => seq(
      'for', '(',
      field('init', optional($._for_init)),
      ';',
      field('condition', optional($._expression)),
      ';',
      field('increment', optional($._expression)),
      ')',
      field('body', $._statement),
    ),

    _for_init: $ => choice(
      seq(
        optional('const'),
        field('type', $._type),
        field('name', $.identifier),
        optional(seq('=', field('value', $._expression))),
      ),
      $._expression,
    ),

    // ---- For-Each ----
    for_each_statement: $ => seq(
      'for', '(',
      field('type', $._type),
      field('variable', $.identifier),
      optional(seq(',', field('key_type', $._type), field('key_variable', $.identifier))),
      ':',
      field('iterable', $._expression),
      ')',
      field('body', $._statement),
    ),

    // ---- Switch ----
    switch_statement: $ => seq(
      'switch', '(', field('value', $._expression), ')',
      '{',
      repeat(choice($.case_clause, $.default_clause)),
      '}',
    ),

    case_clause: $ => seq(
      'case', field('value', $._expression), ':',
      repeat($._statement),
    ),

    default_clause: $ => seq(
      'default', ':',
      repeat($._statement),
    ),

    // ---- Try-Catch ----
    try_statement: $ => seq(
      'try', field('body', $.block),
      repeat($.catch_clause),
    ),

    catch_clause: $ => seq(
      'catch', '(', field('type', $._type), field('name', $.identifier), ')',
      field('body', $.block),
    ),

    // ---- Throw ----
    throw_statement: $ => seq('throw', field('value', $._expression), ';'),

    // ---- Defer ----
    defer_statement: $ => seq(
      'defer',
      field('body', $._statement),
    ),

    // ---- Return ----
    return_statement: $ => seq('return', optional(field('value', $._expression)), ';'),

    // ---- Break / Continue ----
    break_statement: $ => seq('break', ';'),
    continue_statement: $ => seq('continue', ';'),

    // ---- Goto / Label ----
    goto_statement: $ => seq('goto', field('label', $.identifier), ';'),
    labeled_statement: $ => seq(field('label', $.identifier), ':', $._statement),

    // =========================================================================
    // EXPRESSIONS (precedence chain, lowest → highest)
    // =========================================================================

    _expression: $ => $._assignment_expression,

    // Assignment (lowest precedence, right-associative)
    _assignment_expression: $ => choice(
      prec.right(1, seq(
        field('left', $._conditional_expression),
        field('operator', choice(
          '=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '<<=', '>>=',
        )),
        field('right', $._assignment_expression),
      )),
      $._conditional_expression,
    ),

    // Ternary (right-associative)
    _conditional_expression: $ => choice(
      prec.right(2, seq(
        field('condition', $._binary_expression_3),
        '?',
        field('consequence', $._expression),
        ':',
        field('alternative', $._conditional_expression),
      )),
      $._binary_expression_3,
    ),

    // Logical (OR, AND)
    _binary_expression_3: $ => choice(
      prec.left(3, seq(field('left', $._binary_expression_3), field('operator', choice('||', '&&')), field('right', $._binary_expression_4))),
      $._binary_expression_4,
    ),

    // Equality / Comparison
    _binary_expression_4: $ => choice(
      prec.left(4, seq(field('left', $._binary_expression_4), field('operator', choice('==', '!=', '<', '>', '<=', '>=', '<=>')), field('right', $._binary_expression_5))),
      $._binary_expression_5,
    ),

    // Bitwise / Shift
    _binary_expression_5: $ => choice(
      prec.left(5, seq(field('left', $._binary_expression_5), field('operator', choice('|', '^', '&', '<<', '>>')), field('right', $._binary_expression_6))),
      $._binary_expression_6,
    ),

    // Additive
    _binary_expression_6: $ => choice(
      prec.left(6, seq(field('left', $._binary_expression_6), field('operator', choice('+', '-')), field('right', $._binary_expression_7))),
      $._binary_expression_7,
    ),

    // Multiplicative
    _binary_expression_7: $ => choice(
      prec.left(7, seq(field('left', $._binary_expression_7), field('operator', choice('*', '/', '%')), field('right', $._cast_expression))),
      $._cast_expression,
    ),

    // Cast expressions
    _cast_expression: $ => choice(
      seq(
        field('cast_type', choice(
          'cast', 'static_cast', 'reinterpret_cast', 'const_cast',
        )),
        '<', field('type', $._type), '>',
        '(', field('value', $._expression), ')',
      ),
      seq(
        '(',
        field('type', choice($.primitive_type, $.identifier, $.scope_type)),
        ')',
        field('value', $._cast_expression),
      ),
      $._unary_expression,
    ),

    // Unary expressions
    _unary_expression: $ => choice(
      prec(13, seq(
        field('operator', choice(
          '++', '--', '+', '-', '!', '~', '*', '&',
        )),
        field('argument', $._unary_expression),
      )),
      // new expression
      prec(13, seq(
        'new',
        field('type', $._type),
        optional(seq('[', field('array_size', $._expression), ']')),
        optional(seq('(', optional(commaSep1($._expression)), ')')),
      )),
      // delete expression
      prec(13, seq(
        choice('delete', 'delete[]'),
        field('argument', $._unary_expression),
      )),
      // sizeof
      prec(13, seq(
        'sizeof',
        '(',
        choice(field('type', $._type), field('value', $._expression)),
        ')',
      )),
      // offsetof
      prec(13, seq(
        'offsetof',
        '(',
        field('type', $._type),
        ',',
        field('member', $.identifier),
        ')',
      )),
      // move
      prec(13, seq('move', '(', field('value', $._expression), ')')),
      // decltype
      prec(13, seq('decltype', '(', field('value', $._expression), ')')),
      $._postfix_expression,
    ),

    // Template function call: func<T>(args)
    _template_call: $ => prec(16, seq(
      field('function', $.identifier),
      '<', commaSep($._type), optional(','), '>',
      field('arguments', $.argument_list),
    )),

    // Postfix expressions
    _postfix_expression: $ => choice(
      // Template call
      $._template_call,
      // Function call
      prec(14, seq(
        field('function', $._postfix_expression),
        field('arguments', $.argument_list),
      )),
      // Subscript
      prec(14, seq(
        field('object', $._postfix_expression),
        '[',
        field('index', $._expression),
        ']',
      )),
      // Member access
      prec(14, seq(
        field('object', $._postfix_expression),
        choice('.', '->'),
        field('member', $.identifier),
      )),
      // Scope access
      prec(14, seq(
        field('scope', $._postfix_expression),
        '::',
        field('member', $.identifier),
      )),
      // Postfix increment/decrement
      prec(14, seq(
        field('argument', $._postfix_expression),
        field('operator', choice('++', '--')),
      )),
      // Pointer-to-member call
      prec(14, seq(
        field('object', $._postfix_expression),
        '.*',
        field('pmf', $._postfix_expression),
      )),
      prec(14, seq(
        field('object', $._postfix_expression),
        '->*',
        field('pmf', $._postfix_expression),
      )),
      $._primary_expression,
    ),

    argument_list: $ => seq('(', optional(commaSep($._expression)), ')'),

    // Primary expressions
    _primary_expression: $ => choice(
      $.identifier,
      $.number_literal,
      $.string_literal,
      $.f_string_literal,
      $.char_literal,
      $.boolean_literal,
      $.null_literal,
      $.this_expression,
      $.parenthesized_expression,
      $.lambda_expression,
      $.match_expression,
      $.designated_initializer,
      $.initializer_list,
      $.scope_resolution,
    ),

    // ---- Expression sub-types ----
    identifier: $ => /[A-Za-z_][A-Za-z0-9_]*/,
    parenthesized_expression: $ => seq('(', $._expression, ')'),

    scope_resolution: $ => prec(1, seq($.identifier, '::', $.identifier)),

    this_expression: $ => 'this',

    // ---- Match Expression ----
    match_expression: $ => seq(
      'match', '(', field('value', $._expression), ')',
      '{',
      commaSep(choice(
        $.match_arm,
        $.match_default_arm,
      )),
      optional(','),
      '}',
    ),

    match_arm: $ => seq(
      optional('case'),
      field('pattern', $._expression),
      '=>',
      field('body', choice($._expression, $.block)),
    ),

    match_default_arm: $ => seq(
      '_', '=>',
      field('body', choice($._expression, $.block)),
    ),

    // ---- Lambda ----
    lambda_expression: $ => choice(
      // Arrow lambda: (params) => expr / { body }
      seq(
        field('parameters', $.parameter_list),
        '=>',
        field('body', choice($._expression, $.block)),
      ),
      // Capture lambda: [captures](params) -> type { body }
      seq(
        optional(seq(
          '[',
          optional(field('captures', $.capture_list)),
          ']',
        )),
        field('parameters', $.parameter_list),
        optional(seq('->', field('return_type', $._type))),
        field('body', $.block),
      ),
    ),

    capture_list: $ => commaSep1(choice(
      seq('&', $.identifier),
      $.identifier,
    )),

    // ---- Designated Initializer ----
    designated_initializer: $ => seq(
      optional(field('type', $._type)),
      '{',
      commaSep(choice(
        $._expression,
        $.designated_field,
      )),
      optional(','),
      '}',
    ),

    designated_field: $ => seq('.', field('name', $.identifier), '=', field('value', $._expression)),

    initializer_list: $ => seq(
      '{',
      commaSep($._expression),
      optional(','),
      '}',
    ),

    // =========================================================================
    // LITERALS
    // =========================================================================

    number_literal: $ => choice(
      token(seq(/0[xX][0-9a-fA-F_]+/, optional(/_[A-Za-z_][A-Za-z0-9_]*/))),   // hex, optional UDL
      token(seq(/0[bB][01_]+/, optional(/_[A-Za-z_][A-Za-z0-9_]*/))),             // binary, optional UDL
      token(seq(/(\d+\.\d*|\.\d+)([eE][+-]?\d+)?[fF]?/, optional(/_[A-Za-z_][A-Za-z0-9_]*/))), // float, optional UDL
      token(seq(/\d[\d_]*/, optional(/_[A-Za-z_][A-Za-z0-9_]*/))),                // decimal, optional UDL
    ),

    string_literal: $ => seq(
      '"',
      repeat(choice(
        token.immediate(/[^"\\]+/),
        $.escape_sequence,
      )),
      '"',
    ),

    f_string_literal: $ => seq(
      'f', '"',
      repeat(choice(
        token.immediate(/[^"\\{]+/),
        $.escape_sequence,
        $.interpolation,
      )),
      '"',
    ),

    interpolation: $ => seq('{', $._expression, '}'),

    char_literal: $ => seq(
      "'",
      choice($.escape_sequence, token.immediate(/[^'\\]/)),
      "'",
    ),

    escape_sequence: $ => token.immediate(
      /\\(x[0-9A-Fa-f]{1,4}|u[0-9A-Fa-f]{1,8}|.)/,
    ),

    boolean_literal: $ => choice('true', 'false'),
    null_literal: $ => choice('null', 'nullptr'),

    // ---- Comment ----
    comment: $ => choice(
      seq('//', /.*/),
      seq('/*', /[^*]*\*+([^/*][^*]*\*+)*/, '/'),
    ),

    // =========================================================================
    // TYPES
    // =========================================================================

    _type: $ => choice(
      $.primitive_type,
      $.identifier,
      $.pointer_type,
      $.reference_type,
      $.array_type,
      $.nullable_type,
      $.generic_type,
      $.scope_type,
    ),

    primitive_type: $ => choice(
      'void', 'bool', 'char', 'wchar', 'wchar_t',
      'int8', 'int16', 'int32', 'int64',
      'uint8', 'uint16', 'uint32', 'uint64',
      'aint8', 'aint16', 'aint32', 'aint64',
      'float32', 'float64', 'float', 'double',
      'string', 'wstring', 'size_t', 'auto',
    ),

    pointer_type: $ => prec(15, seq(
      field('base', $._type),
      '*',
    )),

    reference_type: $ => prec(15, seq(
      field('base', $._type),
      '&',
    )),

    array_type: $ => prec(15, seq(
      field('base', $._type),
      '[]',
    )),

    nullable_type: $ => prec(14, seq(
      'nullable',
      field('base', $._type),
    )),

    generic_type: $ => seq(
      field('base', $.identifier),
      '<',
      commaSep($._type),
      optional(','),
      '>',
    ),

    scope_type: $ => prec(1, seq(
      field('scope', $.identifier),
      '::',
      field('name', $.identifier),
    )),

  },
});

// Helper: comma-separated list (zero or more, trailing comma optional)
function commaSep(rule) {
  return optional(seq(
    rule,
    repeat(seq(',', rule)),
    optional(','),
  ));
}

// Helper: comma-separated list (one or more, trailing comma optional)
function commaSep1(rule) {
  return seq(
    rule,
    repeat(seq(',', rule)),
    optional(','),
  );
}
