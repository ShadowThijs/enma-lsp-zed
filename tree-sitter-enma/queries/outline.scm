; Enma outline queries
; Shows document structure in Zed's outline/symbol panel

(function_definition
  name: (identifier) @name
  body: (compound_statement) @body) @item

(struct_definition
  name: (identifier) @name
  body: (_) @body) @item

(class_definition
  name: (identifier) @name
  body: (_) @body) @item

(enum_definition
  name: (identifier) @name
  body: (_) @body) @item

(interface_definition
  name: (identifier) @name
  body: (_) @body) @item

(namespace_definition
  name: (identifier) @name
  body: (_) @body) @item

(coroutine_definition
  name: (identifier) @name
  body: (compound_statement) @body) @item
