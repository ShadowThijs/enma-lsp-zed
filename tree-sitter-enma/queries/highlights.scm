; Enma syntax highlighting — flat grammar queries for Zed

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
"nullptr" @constant.builtin

; ---- this ----
"this" @variable.builtin

; ---- Preprocessor ----
(preprocessor) @preproc
(preprocessor "#" @preproc)

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
  "=" "+=" "-=" "*=" "/=" "%=" "&=" "|=" "^="
  "||" "&&"
  "==" "!=" "<" ">" "<=" ">="
  "|" "^" "&"
  "+" "-" "*" "/" "%"
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
  "operator" "function"
] @keyword)

; ---- Templates ----
([
  "template" "typename"
] @keyword)

; ---- Declaration qualifiers ----
([
  "const" "constexpr" "auto" "nullable"
  "extern" "out" "delegate" "coroutine"
  "static"
] @keyword)

; ---- Object lifetime ----
([
  "new" "delete"
] @keyword)

; ---- Access ----
([
  "private" "public" "protected"
] @keyword)

; ---- Cast / built-in ops ----
([
  "cast" "static_cast" "reinterpret_cast" "const_cast"
  "sizeof" "typeof"
] @keyword)

; ---- Primitive types ----
([
  "bool" "char" "wchar"
  "int8" "int16" "int32" "int64"
  "uint8" "uint16" "uint32" "uint64"
  "aint8" "aint16" "aint32" "aint64"
  "float32" "float64" "float" "double"
  "string" "wstring" "void" "size_t"
] @type.builtin)

; ---- Math types ----
([
  "vec2" "vec3" "vec4"
] @type)

; ---- Container types ----
([
  "array" "map" "hash_set" "sorted_map" "variant"
] @type)

; ---- SDK types ----
([
  "coroutine_t" "atomic_int32" "atomic_int64"
  "mutex" "cond_var" "lock_guard"
  "file_t" "regex" "json_value"
] @type)

; ---- Misc keywords ----
([
  "abstract" "final" "shared" "inline"
  "volatile" "get" "set"
  "typedef"
] @keyword)
