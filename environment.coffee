Reader = require('./reader')
repl = require('repl')
writer = require('./writer')
codegen = require 'escodegen'

print = (args...) -> console.log require('util').inspect(args, false, 20)

pre = require './prelude'

class CommonJSModuleLoader
  require: (ns, name) ->
    require(name)

class Environment

  constructor: ->
    @reader = new Reader()
    @module_loader = new CommonJSModuleLoader()
    @context =
      scope: new writer.Scope
      env: {
        terr$: pre
        uses$: []
        imports$: []
        ns$: ""
      }
      js: []

    @uses_len = 0
    @imports_len = 0
    @args = {}

  check_imports: ->
    if @context.env.uses$.length > @uses_len
      new_uses = @context.env.uses$.slice(@uses_len)
      for use in new_uses
        console.log 'USED', use
        @args[use.munged] = @module_loader.require(@context.env.ns$, use.path)

      @uses_len = @context.env.uses$.length

  eval_ast: (ast) ->
    if ast.type.match(/(Expression|Literal)$/)
      ast = {type: 'ReturnStatement', argument: ast}

    # print ast

    js = codegen.generate(ast)
    try
      keys = ['$env']
      values = [@context.env]
      for key, value of @args
        keys.push key
        values.push value

      fn_js = "(function (js) { return new Function('#{keys.join('\', \'')}', js) })"
      fn = eval(fn_js)

      result = fn(js).apply(null, values)
    catch exc
      result = exc

    # console.log js

    result

  eval: (str) ->
    forms = @reader.readString(str)

    for form in forms
      gen = writer.asm(form, @context.env, @context.scope.newScope())
      @check_imports()
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

console.log env.eval require('fs').readFileSync('./test.trbl', 'utf-8')
console.log env.js()
