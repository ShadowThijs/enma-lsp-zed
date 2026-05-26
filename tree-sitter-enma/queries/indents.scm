; Enma indentation queries - structured grammar

; Indent after opening braces
(block "{" @indent)
(struct_body "{" @indent)
(class_body "{" @indent)
(enum_declaration "{" @indent)
(namespace_definition "{" @indent)
(switch_statement "{" @indent)
(initializer_list "{" @indent)
(designated_initializer "{" @indent)

; Indent after control flow without braces
(if_statement consequence: (_) @indent)
(if_statement alternative: (_) @indent)
(while_statement body: (_) @indent)
(for_statement body: (_) @indent)
(for_each_statement body: (_) @indent)
(do_statement body: (_) @indent)
