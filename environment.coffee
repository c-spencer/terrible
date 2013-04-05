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
            body.concat([
              JS.Return(JS.Identifier('$env'))
            ])
          )
        ]
      ) # End Call
    ) # End Expression
  ]) # End Program

class Environment

  constructor: ->
    @reader = new Reader()
    @module_loader = new CommonJSModuleLoader()
    @context =
      scope: new writer.Scope
      env: {
        terr$: pre
        requires$: []
        ns$: ""
      }
      js: []

    @requires_len = 0
    @deps = []

  check_imports: ->
    if @context.env.requires$.length > @requires_len
      new_requires = @context.env.requires$.slice(@requires_len)
      for req in new_requires
        console.log 'REQUIRED', req
        @deps.push
          munged: req.munged
          path: req.path
          value: @module_loader.require(@context.env.ns$, req.path)

      @requires_len = @context.env.requires$.length

  eval_ast: (ast) ->
    if ast.type.match(/(Expression|Literal)$/)
      ast = {type: 'ReturnStatement', argument: ast}

    # print ast

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
    js = @context.js.map(@force_statement)
    ast = ModuleWrapper(@context.env.ns$, @deps, js)
    # require('fs').writeFileSync('genast.js', require('util').inspect(ast, false, 20))
    codegen.generate(ast)

  repl_eval = (s, context, filename, cb) ->
    s = s.replace(/^\(/, '').replace(/\)$/, '')
    result = @eval(s)
    cb null, result

env = new Environment

console.log env.eval require('fs').readFileSync('./test.trbl', 'utf-8')
console.log env.js()
