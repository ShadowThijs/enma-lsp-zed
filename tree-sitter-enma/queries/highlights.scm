; Enma syntax highlighting — structured grammar queries for Zed

; === COMMENTS ===
(comment) @comment

; === STRINGS AND CHARS ===
(string_literal) @string
(f_string_literal) @string
(char_literal) @string
(escape_sequence) @string.escape
(interpolation "{" @punctuation.special "}" @punctuation.special)

; === NUMBERS ===
(number_literal) @number

; === LITERALS ===
(boolean_literal) @boolean
(null_literal) @constant.builtin
(this_expression) @variable.builtin

; === IDENTIFIERS ===
(identifier) @variable

; === FUNCTION DEFINITION NAMES ===
(function_definition name: (identifier) @function)
(function_declaration name: (identifier) @function)
(method_declaration name: (identifier) @function.method)
(constructor_declaration name: (identifier) @constructor)
(destructor_declaration (identifier) @constructor)

; === TYPE NAMES ===
(struct_declaration name: (identifier) @type)
(class_declaration name: (identifier) @type)
(interface_declaration name: (identifier) @type)
(enum_declaration name: (identifier) @type)
(generic_type base: (identifier) @type)

; === FIELD / PROPERTY NAMES ===
(field_declaration name: (identifier) @property)
(property_declaration name: (identifier) @property)
(designated_field name: (identifier) @property)

; === PARAMETER NAMES ===
(parameter_declaration name: (identifier) @variable.parameter)

; === NAMESPACE / LABEL ===
(namespace_definition name: (identifier) @namespace)
(goto_statement label: (identifier) @label)

; === PREPROCESSOR ===
(preproc_directive) @preproc

; === ANNOTATIONS ===
(annotation) @attribute

; === OPERATOR OVERLOADS ===
(operator_overload "operator" @keyword)

; === PROPERTY ACCESSORS ===
(getter "get" @keyword)
(setter "set" @keyword)

; === ACCESS SPECIFIERS ===
(access_specifier) @keyword

; === PRIMITIVE TYPES ===
(primitive_type) @type.builtin

; === PUNCTUATION ===
("(" @punctuation.bracket)
(")" @punctuation.bracket)
("{" @punctuation.bracket)
("}" @punctuation.bracket)
("[" @punctuation.bracket)
("]" @punctuation.bracket)
(";" @punctuation.delimiter)
("," @punctuation.delimiter)
("." @punctuation.delimiter)
(":" @punctuation.delimiter)
("::" @punctuation.special)
("->" @punctuation.special)
("..." @punctuation.special)

; === COMPOUND TYPE SIGILS ===
(pointer_type "*" @type.builtin)
(reference_type "&" @type.builtin)
(array_type "[]" @type.builtin)
(nullable_type "nullable" @keyword)

; === OPERATORS ===
[
  "=" "+=" "-=" "*=" "/=" "%=" "&=" "|=" "^=" "<<=" ">>="
  "||" "&&"
  "==" "!=" "<" ">" "<=" ">=" "<=>"
  "|" "^" "&" "+" "-" "*" "/" "%" "<<" ">>"
  "++" "--" "!" "~" "?"
] @operator

; === KEYWORDS — Control Flow ===
[
  "if" "else" "for" "while" "do"
  "switch" "case" "default"
  "break" "continue" "return"
  "try" "catch" "throw"
  "defer" "goto" "match"
] @keyword

; === KEYWORDS — Module / Import ===
[
  "import" "using" "namespace"
] @keyword.import

; === KEYWORDS — OOP ===
[
  "class" "struct" "interface" "mixin" "enum"
  "virtual" "override" "final" "property"
] @keyword

; === KEYWORDS — Templates ===
[
  "template" "typename"
] @keyword

; === KEYWORDS — Qualifiers / Storage ===
[
  "const" "constexpr" "auto" "nullable"
  "extern" "out" "delegate" "coroutine"
  "static" "inline"
] @keyword

; === KEYWORDS — Memory ===
[
  "new" "delete"
] @keyword

; === KEYWORDS — Cast / Built-in ===
[
  "cast" "static_cast" "reinterpret_cast" "const_cast"
  "sizeof" "move" "offsetof" "decltype" "static_assert"
] @keyword

; === KEYWORDS — Access ===
[
  "private" "public" "protected"
] @keyword
