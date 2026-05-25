; Enma outline queries — structured grammar

(function_definition
  name: (identifier) @name
  body: (block) @body) @item

(function_declaration
  name: (identifier) @name) @item

(struct_declaration
  name: (identifier) @name
  body: (struct_body) @body) @item

(class_declaration
  name: (identifier) @name
  body: (class_body) @body) @item

(interface_declaration
  name: (identifier) @name) @item

(enum_declaration
  name: (identifier) @name) @item

(namespace_definition
  name: (identifier) @name
  body: (_) @body) @item

(global_variable_declaration
  name: (identifier) @name) @item

(type_alias
  alias: (identifier) @name) @item

(method_declaration
  name: (identifier) @name
  body: (block) @body) @item
