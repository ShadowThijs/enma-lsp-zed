; Enma syntax highlighting — flat grammar queries for Zed
; ============================================================================

; ---- Comments ----
(comment) @comment

; ---- Strings ----
(string) @string
(f_string) @string

; ---- Escape sequences ----
(escape) @string.escape

; ---- Interpolation delimiters (f"...{expr}...") ----
(interpolation "{" @punctuation.special "}" @punctuation.special)

; ---- Character literals ----
(char_literal) @string

; ---- Numbers ----
(number) @number

; ---- Boolean and null ----
"true" @boolean
"false" @boolean
"null" @constant.builtin

; ---- this ----
"this" @variable.builtin

; ---- Preprocessor ----
(preprocessor) @preproc
(preprocessor "#" @preproc)

; ---- Annotations ----
(annotation) @attribute
(annotation "[" @punctuation.bracket "]" @punctuation.bracket)

; ---- Bracket punctuation ----
("(" @punctuation.bracket)
(")" @punctuation.bracket)
("{" @punctuation.bracket)
("}" @punctuation.bracket)
("[" @punctuation.bracket)
("]" @punctuation.bracket)

; ---- Delimiter punctuation ----
(";" @punctuation.delimiter)
("," @punctuation.delimiter)
("." @punctuation.delimiter)
(":" @punctuation.delimiter)

; ---- Special punctuation ----
("::" @punctuation.special)
("->" @punctuation.special)
("..." @punctuation.special)

; ---- Operators ----
([
  "=" "+=" "-=" "*=" "/=" "%=" "&=" "|=" "^=" "<<=" ">>="
  "||" "&&"
  "==" "!=" "<" ">" "<=" ">=" "<=>"
  "|" "^" "&"
  "+" "-" "*" "/" "%"
  "<<" ">>"
  "++" "--"
  "!" "~"
  "?" "@"
] @operator)

; ---- Keywords ----
([
  "if" "else" "for" "while" "do"
  "switch" "case" "default"
  "break" "continue" "return"
  "try" "catch" "throw"
  "defer" "yield" "goto"
  "match"
] @keyword)

; ---- Module / namespace ----
([
  "import" "using" "namespace"
] @keyword.import)

; ---- OOP ----
([
  "class" "struct" "interface" "mixin" "enum"
  "virtual" "override" "final" "property"
  "operator"
] @keyword)

; ---- Templates ----
([
  "template" "typename"
] @keyword)

; ---- Declaration qualifiers ----
([
  "const" "constexpr" "auto" "nullable"
  "extern" "out" "delegate" "coroutine"
  "static_assert"
] @keyword)

; ---- Object lifetime ----
([
  "new" "delete"
] @keyword)

; ---- Access ----
([
  "private" "public"
] @keyword)

; ---- Cast / built-in ops ----
([
  "cast" "static_cast" "reinterpret_cast" "const_cast"
  "move" "sizeof" "offsetof" "decltype"
] @keyword)

; ---- Primitive types ----
([
  "bool" "char" "wchar" "wchar_t"
  "int8" "int16" "int32" "int64"
  "uint8" "uint16" "uint32" "uint64"
  "aint8" "aint16" "aint32" "aint64"
  "float32" "float64"
  "string" "wstring" "void"
] @type.builtin)

; ---- Math / addon types ----
([
  "vec2" "vec3" "vec4" "quat" "mat4"
] @type)

; ---- Container types ----
([
  "map" "hash_set" "sorted_map" "variant"
] @type)

; ---- SDK types ----
([
  "coroutine_t" "atomic_int32" "atomic_int64"
  "mutex" "cond_var" "lock_guard"
  "file_t" "regex" "json_value"
  "proc_t" "cpu_t" "ws_t" "udp_t"
  "http_response_t" "sound_t"
] @type)

; ---- Annotation keywords ----
([
  "inline" "noinline" "noopt" "noescape"
  "packed" "reflect" "serialize" "export"
  "dll"
] @attribute)

; ---- Function intrinsics ----
([
  "__asm_rdtsc" "__asm_pause" "__asm_mfence" "__asm_nop"
  "__va_count" "__va_arg"
] @function.builtin)
