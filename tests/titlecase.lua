local H = require("tests.helpers")
H.setup()
local E = require("editing_tools")
local transform = require("editing_tools.transform")
H.eq(
  transform.titlecase({ "the hELLO world", "a walk in the park", "" }),
  { "The Hello World", "A Walk in the Park", "" }
)
H.eq(
  transform.titlecase({ "an api for ios" }, "line", { preserve = { api = "API", ios = "iOS" } }),
  { "An API for iOS" }
)
H.eq(transform.titlecase({ "a study of x" }, "line", { small_words = {} }), { "A Study Of X" })
H.buffer({ "the hELLO world", "leave untouched" })
assert(E.titlecase(1, 1))
H.eq(H.lines(), { "The Hello World", "leave untouched" })
H.keys("u")
H.eq(H.lines(), { "the hELLO world", "leave untouched" })
-- The same transform supports character ranges and native operator repeat.
E.apply("titlecase", { start = { 0, 4 }, finish = { 0, 9 }, mode = "char" })
H.eq(H.lines()[1], "the Hello world")
assert(not E.titlecase(2, 2, { preserve = { leave = "leave", untouched = "untouched" } }))
print("Titlecase: line/character ranges, one undo, unchanged edits and explicit acronyms passed")
