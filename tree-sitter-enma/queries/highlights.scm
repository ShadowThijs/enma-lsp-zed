; Enma syntax highlighting — tree-sitter queries for Zed
; ============================================================================

; ---- Comments ----
(comment) @comment

; ---- String literals ----
(string_literal) @string

; ---- Number literals ----
(number_literal) @number

; ---- Boolean and null literals ----
(boolean_literal) @boolean
(null_literal) @constant.builtin

; ---- Primitive types ----
(primitive_type) @type.builtin

; ---- User-defined types ----
(type_identifier) @type

; ---- Preprocessor ----
(preprocessor_directive) @preproc

; ---- Annotations ----
(annotation) @attribute

; ---- this ----
(this_expression) @variable.builtin

; ---- Functions ----
(function_definition name: (identifier) @function)
(template_declaration body: (function_definition name: (identifier) @function))
(coroutine_definition name: (identifier) @function)

; ---- Function calls ----
(call_expression function: (identifier) @function.call)
(call_expression function: (field_expression field: (field_identifier) @function.call))
(call_expression function: (pointer_expression field: (field_identifier) @function.call))

; ---- Methods ----
(method_definition name: (field_identifier) @function.method)

; ---- Constructors / Destructors ----
(constructor_definition name: (identifier) @constructor)
(destructor_definition name: (identifier) @constructor)

; ---- Parameters ----
(parameter_declaration name: (identifier) @variable.parameter)

; ---- Field access ----
(field_expression field: (field_identifier) @property)

; ---- Pointer access ----
(pointer_expression field: (field_identifier) @property)

; ---- Scope access ----
(scope_expression name: (identifier) @constant)

; ---- Struct/class/enum/interface names ----
(struct_definition name: (type_identifier) @type)
(class_definition name: (type_identifier) @type)
(enum_definition name: (type_identifier) @type)
(interface_definition name: (type_identifier) @type)

; ---- Enum members ----
(enum_definition (identifier) @enum)

; ---- Namespace names ----
(namespace_definition name: (identifier) @namespace)

; ---- goto labels ----
(labeled_statement label: (identifier) @label)

; ---- Template declarations ----
(template_declaration name: (type_identifier) @type)

; ---- Operators ----
[
  "+" "-" "*" "/" "%"
  "==" "!=" "<" ">" "<=" ">="
  "&&" "||" "!"
  "&" "|" "^" "~"
  "=" "+=" "-=" "*=" "/=" "%="
  "&=" "|=" "^=" "<<=" ">>="
  "++" "--"
  "->" "=>" "::"
] @operator

; ---- Punctuation ----
[
  "(" ")" "{" "}" "[" "]" "<" ">"
] @punctuation.bracket

[
  "." "," ";" ":"
] @punctuation.delimiter
