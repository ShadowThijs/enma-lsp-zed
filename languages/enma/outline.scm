; Enma outline queries - structured grammar

(function_definition
  name: (identifier) @name) @item

(function_declaration
  name: (identifier) @name) @item

(struct_declaration
  name: (identifier) @name) @item

(class_declaration
  name: (identifier) @name) @item

(interface_declaration
  name: (identifier) @name) @item

(enum_declaration
  name: (identifier) @name) @item

(namespace_definition
  name: (identifier) @name) @item

(global_variable_declaration
  name: (identifier) @name) @item

(type_alias
  alias: (identifier) @name) @item

(method_declaration
  name: (identifier) @name) @item
