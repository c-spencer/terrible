Reader = require('./reader')
repl = require('repl')
writer = require('./writer')
codegen = require 'escodegen'
JS = require './js'

print = (args...) -> console.log require('util').inspect(args, false, 20)

pre = require './prelude'

class CommonJSModuleLoader
  require: (ns, name) ->
    require(name)

require.extensions['.trbl'] = (module, filename) ->
  env = Environment.fromFile(filename)
  module.exports = env.context.env

ModuleWrapper = (ns, deps, body) ->
  JS.Program([
    JS.ExpressionStatement(
      JS.CallExpression(
        JS.FunctionExpression( # function (root, factory)
          [JS.Identifier('root'), JS.Identifier('factory')]
          [
            JS.IfStatement( # if typeof exports === 'object'
              JS.BinaryExpression(
                JS.UnaryExpression('typeof', JS.Identifier('exports'))
                '==='
                JS.Literal('object')
              )
              JS.Block([ # module.exports = factory(require(dep1)...require(depn))
                JS.ExpressionStatement(
                  JS.AssignmentExpression(
                    JS.MemberExpression(JS.Identifier('module'), JS.Identifier('exports'))
                    '='
                    JS.CallExpression(
                      JS.Identifier('factory')
                      deps.map (dep) ->
                        JS.CallExpression(JS.Identifier('require'), [JS.Literal(dep.path)])
                    )
                  )
                )
              ])
              JS.IfStatement( # if (typeof define === 'function' && define.amd)
                JS.LogicalExpression(
                  JS.BinaryExpression(
                    JS.UnaryExpression('typeof', JS.Identifier('define'))
                    '==='
                    JS.Literal('function')
                  )
                  '&&'
                  JS.MemberExpression(JS.Identifier('define'), JS.Identifier('amd'))
                )
                JS.Block([ # define(deps, factory)
                  JS.ExpressionStatement(
                    JS.CallExpression(
                      JS.Identifier('define')
                      [ # TODO: resolve relative paths
                        JS.ArrayExpression(deps.map((dep) -> dep.path).map(JS.Literal))
                        JS.Identifier('factory')
                      ]
                    )
                  )
                ])
                JS.Block([ # root[ns] = factory(root[dep1] ... root[depn])
                  JS.ExpressionStatement(
                    JS.AssignmentExpression(
                      JS.MemberExpressionComputed(JS.Identifier('root'), JS.Literal(ns))
                      '='
                      JS.CallExpression(
                        JS.Identifier('factory')
                        deps.map (dep) ->
                          JS.MemberExpressionComputed(JS.Identifier('root'), JS.Identifier(dep.path))
                      )
                    )
                  )
                ]) # end alternate
              ) # end typeof define
            ) # end typeof exports
          ]
        ) # end function (root, factory)
        [
          { type: 'ThisExpression' }
          JS.FunctionExpression(
            deps.map((dep) -> JS.Identifier(dep.munged))
            [JS.VariableDeclaration([
              JS.VariableDeclarator(JS.Identifier('$env'), JS.ObjectExpression([]))
            ])].concat(body, [JS.Return(JS.Identifier('$env'))])
          )
        ]
      ) # End Call
    ) # End Expression
  ]) # End Program

class Environment

  @loaded = {}

  @fromFile: (path) ->
    path = require('path').resolve(path)
    if !Environment.loaded[path]
      Environment.loaded[path] = new Environment
      Environment.loaded[path].eval require('fs').readFileSync(path, 'utf-8')
      Environment.loaded[path]

    Environment.loaded[path]

  constructor: ->
    @reader = new Reader()
    @module_loader = new CommonJSModuleLoader()
    @context =
      scope: new writer.Scope
      env: {
        requires$: []
        ns$: ""
      }
      js: []

    @requires_len = 0
    @deps = []

    # prep the environment
    @eval '(require [terr$ "./prelude"])'

  check_imports: ->
    if @context.env.requires$.length > @requires_len
      new_requires = @context.env.requires$.slice(@requires_len)
      for req in new_requires
        spec =
          munged: req.munged
          path: req.path
          value: @module_loader.require(@context.env.ns$, req.path)
        @deps.push spec

      @requires_len = @context.env.requires$.length

  eval_ast: (ast) ->
    if ast.type.match(/(Expression|Literal|Identifier)$/)
      ast = {type: 'ReturnStatement', argument: ast}

    js = codegen.generate(ast)
    try
      keys = ['$env']
      values = [@context.env]
      for dep in @deps
        keys.push dep.munged
        values.push dep.value

      fn_js = "(function (js) { return new Function('#{keys.join('\', \'')}', js) })"
      fn = eval(fn_js)

      result = fn(js).apply(null, values)
    catch exc
      result = exc

    # console.log js

    result

  eval: (str, read_result=false) ->
    forms = @reader.readString(str)

    for form, i in forms
      if read_result
        form.$statement = i < (forms.length - 1)
      else
        form.$statement = true

      gens = writer.asm(form, @context.env, @context.scope.newScope())

      if !gens.$explode
        gens = [gens]
      @check_imports()
      for gen in gens
        @context.js.push(gen)
        result = @eval_ast(gen)

    result

  repl: ->
    @repl_session = repl.start
      eval: @repl_eval
      prompt: 'terrible> '

  force_statement: (node) ->
    if node.type.match(/(Expression|Literal|Identifier)$/)
      node = {type: 'ExpressionStatement', expression: node}
    else
      node

  js: ->
    js = @context.js.map(@force_statement)
    ast = ModuleWrapper(@context.env.ns$, @deps, js)
    # require('fs').writeFileSync('genast.js', require('util').inspect(ast, false, 20))
    codegen.generate(ast)

  repl_eval = (s, context, filename, cb) ->
    s = s.replace(/^\(/, '').replace(/\)$/, '')
    result = @eval(s)
    cb null, result

env = Environment.fromFile('./core.trbl')
console.log env.js()
# env = Environment.fromFile('./test.trbl')
# console.log env.js()
