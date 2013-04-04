Reader = require('./reader')
repl = require('repl')
writer = require('./writer')
codegen = require 'escodegen'

print = (args...) -> console.log require('util').inspect(args, false, 20)

pre = require './prelude'

class Environment

  constructor: ->
    @reader = new Reader()
    @context =
      scope: new writer.Scope
      env: {
        terr$: pre
      }
      js: []

  eval_ast: (ast) ->
    if ast.type.match(/(Expression|Literal)$/)
      ast = {type: 'ReturnStatement', argument: ast}
    js = codegen.generate(ast)
    try
      result = new Function('$env', js)(@context.env)
    catch exc
      result = exc

    result

  eval: (str) ->
    forms = @reader.readString(str)

    for form in forms
      gen = writer.asm(form, @context.env, @context.scope.newScope())
      @context.js.push(gen)
      result = @eval_ast(gen)

    result

  repl: ->
    @repl_session = repl.start
      eval: @repl_eval
      prompt: 'terrible> '

  force_statement: (node) ->
    if node.type.match(/(Expression|Literal)$/)
      node = {type: 'ExpressionStatement', expression: node}
    else
      node

  js: ->
    codegen.generate(type: 'Program', body: @context.js.map(@force_statement))

  repl_eval = (s, context, filename, cb) ->
    s = s.replace(/^\(/, '').replace(/\)$/, '')
    result = @eval(s)
    cb null, result

env = new Environment

console.log env.eval """
  (def inc (fn [x] (+ x 1)))

  (inc 1)

  (def splice (macro [& e] `(+ 4 5 ~@e 6 3)))

  (splice 1 2)

  [1 2 3 @body 4 5 6]

  (def x 10)

  (let [x x [a b] x] x)

  (let [{a :a b :b} {:a 6 :b 7} y 15] (+ a b y))

  (if (> 7 6)
    (do
      (console.log "All's \\" well")
      7)
    (do
      (console.log "Oh hum, numbers have broken.")
      6))
"""

console.log env.js()
