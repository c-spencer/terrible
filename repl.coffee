Reader = require('./reader')
repl = require('repl')
writer = require('./writer')
codegen = require 'escodegen'

print = (args...) -> console.log require('util').inspect(args, false, 20)

reader = new Reader()

# result = reader.readString """
#   (let [a (+ 1 1)
#         b (+ a 2)
#         {c :a d :b} {:a 5 :b 1}]
#     (+ a b c d))

#   (defn add-pair [[a b]] (+ a b))
# """

# result = reader.readString """
#   #(+ % %2 %6 %& 1)
# """

# result = reader.readString """
#   (defmacro twice [e] `(+ ~e ~e))
# """

# result = reader.readString """
#   (Backbone.Model. "a" "b")
# """

# result = reader.readString """
#   (def inc (fn [x] inc))
# """

# print result

# start = +new Date

# for i in [0..100000]
#   reader.readString """
#     #(+ % 1)
#   """

# console.log((+new Date - start)/100000)

repl_eval = (s, context, filename, cb) ->
  if !cb
    console.log "terrible> #{s}"

  try
    ast = reader.readString(s)
    # print ast
    gen = writer.asm(ast, context.env, context.scope.newScope())
    # print gen
    result = eval_in_env(context.env, gen)
  catch exc
    result = exc

  if cb
    cb(null, result)
  else
    console.log ">", result
    console.log()

repl_eval_ = (s, context, filename, cb) ->
  s = s.replace(/^\(/, '').replace(/\)$/, '')
  result = repl_eval(s, context, filename, cb)

eval_in_env = (env, ast) ->
  if ast.type.match(/Expression$/)
    ast = {type: 'ReturnStatement', argument: ast}
  js = codegen.generate(ast)
  console.log js
  try
    result = new Function('$env', js)(env)
  catch exc
    result = exc
  result

context =
  scope: new writer.Scope
  env: {}

pre = require './prelude'

context.env["terr$"] = pre

repl_eval("(def inc (fn [x] (+ x 1)))", context)
repl_eval("(inc 1)", context)
repl_eval("(def twice (macro [& e] `(+ 4 5 ~@e 6 3))))", context)
repl_eval("(twice 1 2)", context)
repl_eval("[1 2 3 @body 4 5 6]", context)
repl_eval("(def x 10)", context)
repl_eval("(let [x x [a b] x] x)", context)
repl_eval("(let [{a :a b :b} {:a 6 :b 7} y 15] (+ a b y))", context)

# repl_eval """
#   (if (> 7 6)
#     (console.log "All's \\" well")
#     (do
#       (console.log "Oh hum, numbers have broken.")
#       7)))
# """, context

# repl_session = repl.start
#   eval: repl_eval_
#   prompt: "terrible> "

# repl_session.context = context
