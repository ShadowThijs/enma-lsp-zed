; ============================================================================
; Enma syntax highlighting — tree-sitter queries for Zed
; ============================================================================

; ---- Comments ----
(comment) @comment

; ---- String literals ----
(string_literal) @string

; ---- Escape sequences (inside strings) ----
(escape_sequence) @string.escape

; ---- Number literals ----
(number_literal) @number

; ---- Boolean and null literals ----
(boolean_literal) @boolean
(null_literal) @constant.builtin

; ---- Primitive types (int32, float64, bool, string, void, etc.) ----
(primitive_type) @type.builtin

; ---- Preprocessor directives ----
(preprocessor_directive) @preproc

; ---- Annotations ([[...]]) ----
(annotation) @attribute

; ---- this ----
(this_expression) @variable.builtin

; ---- Function definitions ----
(function_definition
  name: (identifier) @function)

; ---- Function calls ----
(call_expression
  function: (identifier) @function.call)

(call_expression
  function: (field_expression
    field: (identifier) @function.call))

(call_expression
  function: (pointer_expression
    field: (identifier) @function.call))

; ---- Method definitions ----
(method_definition
  name: (identifier) @function.method)

; ---- Constructors ----
(constructor_definition
  name: (identifier) @constructor)

; ---- Destructors ----
(destructor_definition
  name: (identifier) @constructor)

; ---- Parameters ----
(parameter_declaration
  name: (identifier) @variable.parameter)

; ---- Field access (obj.field) ----
(field_expression
  field: (identifier) @property)

; ---- Pointer access (ptr->field) ----
(pointer_expression
  field: (identifier) @property)

; ---- Scope access (ns::name, Enum::Value) ----
(scope_expression
  name: (identifier) @constant)

; ---- Struct/class/enum names in definitions ----
(struct_definition
  name: (identifier) @type)

(class_definition
  name: (identifier) @type)

(enum_definition
  name: (identifier) @type)

(interface_definition
  name: (identifier) @type)

; ---- Enum members ----
(enum_member
  name: (identifier) @enum)

; ---- Namespace names ----
(namespace_definition
  name: (identifier) @namespace)

; ---- goto labels ----
(labeled_statement
  label: (identifier) @label)

; ---- Operators ----
[
  "+" "-" "*" "/" "%"
  "==" "!=" "<" ">" "<=" ">="
  "&&" "||" "!"
  "&" "|" "^" "~" "<<=" ">>="
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

; ---- Keywords (handled automatically by tree-sitter word token) ----
; The following are extracted from the grammar's keyword tokens:
;   if, else, for, while, do, return, break, continue,
;   switch, case, default, goto, defer, try, catch, throw, yield,
;   import, using, namespace, class, struct, interface, mixin, enum,
;   virtual, override, final, property, operator, template, typename,
;   const, constexpr, auto, nullable, extern, out, delegate, coroutine,
;   typedef, new, delete, sizeof, offsetof, static_assert, decltype,
;   cast, static_cast, reinterpret_cast, const_cast, move,
;   private, public, friend, explicit, inline, noinline, noopt, noescape,
;   packed, reflect, serialize, export, dll, this
; These are automatically highlighted as @keyword by tree-sitter.
