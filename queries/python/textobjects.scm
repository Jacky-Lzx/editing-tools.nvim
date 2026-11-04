(function_definition body: (block) @function.inner) @function.outer
(class_definition body: (block) @class.inner) @class.outer
(if_statement consequence: (block) @conditional.inner) @conditional.outer
(for_statement body: (block) @loop.inner) @loop.outer
(while_statement body: (block) @loop.inner) @loop.outer
(with_statement body: (block) @block.inner) @block.outer
