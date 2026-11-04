(function_declaration body: (block) @function.inner) @function.outer
(function_definition body: (block) @function.inner) @function.outer
(if_statement consequence: (block) @conditional.inner) @conditional.outer
(for_statement body: (block) @loop.inner) @loop.outer
(while_statement body: (block) @loop.inner) @loop.outer
(do_statement body: (block) @block.inner) @block.outer
