Reader = require('./reader')
repl = require('repl')
writer = require('./writer')
codegen = require 'escodegen'
JS = require './js'
path = require 'path'
url = require 'url'

print = (args...) -> console.log require('util').inspect(args, false, 20)

pre = require './src/coffee/prelude'

PathResolver =
  AMD: (ns, name) ->
    if name.match(/^!/)
      return name.substring(1)
    name

  clean: (name) ->
    name.replace(/(^[a-z]*!|\.[a-z]+$)/, '')

  FSRel: (ns, name) ->
    if name.match(/^!/)
      return name.substring(1)

    [full, loader, filepath] = name.match(/^(?:([a-z]+)!)?(.+)$/)

    if loader
      name = "#{filepath}.#{loader}"

    filename = path.basename(name)
    name_root = path.dirname(name)
    ns_root = path.dirname(ns)

    filepath = path.join((path.relative(ns_root, name_root) or "."), filename)

    if filepath.match(/^[^\.]/)
      filepath = "./#{filepath}"

    filepath

  FSAbs: (ns, name, root) ->
    if name.match(/^!/)
      return name.substring(1)

    path.join(path.dirname(root), PathResolver.FSRel(ns, name))


class CommonJSModuleLoader
  require: (ns, name, env_path) ->
    require PathResolver.FSAbs(ns, name, env_path)


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
                        JS.CallExpression(JS.Identifier('require'), [
                          JS.Literal(PathResolver.clean(PathResolver.FSRel(ns, dep.path)))
                        ])
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
                      [
                        JS.ArrayExpression(
                          deps.map((dep) -> JS.Literal(PathResolver.AMD(ns, dep.path)))
                        )
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
                          JS.MemberExpressionComputed(JS.Identifier('root'),
                            JS.Literal(PathResolver.clean(dep.path)))
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

  @compile = false

  @loaded = {}

  @fromFile: (filepath) ->
    filepath = path.resolve(filepath)
    if !Environment.loaded[filepath]
      Environment.loaded[filepath] = new Environment(filepath)
      Environment.loaded[filepath].eval require('fs').readFileSync(filepath, 'utf-8')

      if Environment.compile
        env = Environment.loaded[filepath]
        filename = path.basename(env.context.env.ns$) + ".js"
        require('fs').writeFileSync(path.join(path.dirname(filepath), filename), env.js())

    Environment.loaded[filepath]

  constructor: (@filepath, @compile=false) ->
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

    @prepped = null

  prep: ->
    @prepped = true

    if @repl_session?
      @repl_session.prompt = "terrible (#{@context.env.ns$})> "

    # prep the environment
    @eval '(require [terr$ "coffee/prelude"])
           (require "trbl!trbl/core" :use)'

  check_imports: ->
    if @context.env.requires$.length > @requires_len
      new_requires = @context.env.requires$.slice(@requires_len)
      for req in new_requires
        spec =
          munged: req.munged
          path: req.path
          value: @module_loader.require(@context.env.ns$, req.path, @filepath)
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

      if @context.env.ns$ and !@prepped
        @prep()
      @check_imports()

      if !gens.$explode
        gens = [gens]

      for gen in gens
        @context.js.push(gen)
        result = @eval_ast(gen)

    result

  repl: ->
    if !@context.env.ns$
      @eval('(ns "user")')

    @repl_session = repl.start
      eval: @repl_eval
      prompt: "terrible (#{@context.env.ns$})> "


  repl_eval: (s, context, filename, cb) =>
    s = s.replace(/^\(/, '').replace(/\)$/, '')
    result = @eval(s, true)
    cb null, result

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

# env = Environment.fromFile('./src/trbl/core.trbl')
# console.log env.js()
# env = Environment.fromFile('./src/trbl/test.trbl')
# console.log env.js()

module.exports = Environment
