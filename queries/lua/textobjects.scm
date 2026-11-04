(function_declaration) @function.outer
(function_definition) @function.outer
(function_declaration body: (block) @function.inner)
(function_definition body: (block) @function.inner)
(if_statement) @conditional.outer
(if_statement consequence: (block) @conditional.inner)
(for_statement) @loop.outer
(for_statement body: (block) @loop.inner)
(while_statement) @loop.outer
(while_statement body: (block) @loop.inner)
(do_statement) @block.outer
(do_statement body: (block) @block.inner)
