; Enma indentation queries
; Controls auto-indentation behavior in Zed

; Indent after opening braces
(compound_statement "{" @indent)

; Dedent closing braces
(compound_statement "}" @indent_end)

; Indent struct/class bodies
(struct_definition "{" @indent)
(struct_definition "}" @indent_end)

(class_definition "{" @indent)
(class_definition "}" @indent_end)

; Indent namespace bodies
(namespace_definition "{" @indent)
(namespace_definition "}" @indent_end)

; Indent enum bodies
(enum_definition "{" @indent)
(enum_definition "}" @indent_end)

; Dedent for case/default labels (they're at same level as switch)
(case_statement "case" @indent)
(default_statement "default" @indent)
