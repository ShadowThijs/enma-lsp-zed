; Enma indentation queries — flat grammar
; The grammar is flat (no structured definition nodes),
; so we indent/dedent on braces directly.

("{" @indent)
("}" @indent_end)
