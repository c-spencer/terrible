terribleWalker = require('./walker')
pre = require './prelude'
JS = require './js'
codegen = require 'escodegen'
reader = new(require './reader')

print = (args...) -> console.log require('util').inspect(args, false, 20)

class Scope
  constructor: (@stack = [{}], @quoted = false, @level = 0) ->

  addSymbol: (name, accessor) ->
    @stack[@level][name] = accessor

  newScope: ->
    new_stack = []
    for layer in @stack
      new_layer = {}
      for key, value of layer
        new_layer[key] = value
      new_stack.push new_layer

    if new_stack[@level].length > 0
      new_level = @level + 1
    else
      new_level = @level

    return new Scope(new_stack, @quoted, new_level)

  unquote: -> @quote_(false)
  quote: -> @quote_(true)
  quote_: (quoted) ->
    if quoted == @quoted
      throw "Can't double quote/unquote"

    @quoted = quoted

  resolve: (name) ->
    i = @level
    while i >= 0
      if acc = @stack[i][name]
        return acc
      --i

    return false


generateDestructuring = (lhss, rhss, assign='var') ->
  clauses = []

  for lhs, i in lhss
    rhs = rhss[i]
    if lhs.type == 'Vector'
      if rhs.type == 'Symbol'
        rhs_id = rhs
      else
        rhs_id = pre.Symbol('$rhs')
        clauses.push pre.List(pre.Symbol(assign), rhs_id, rhs)

      for ident, i in lhs
        clauses.push pre.List(
          pre.Symbol(assign)
          ident
          pre.List(pre.Symbol('get'), rhs_id, pre.Literal(i))
        )
    else if lhs.type == 'Hash'

      if rhs.type == 'Symbol'
        rhs_id = rhs
      else
        rhs_id = pre.Symbol('$rhs')
        clauses.push pre.List(pre.Symbol(assign), rhs_id, rhs)

      i = 0
      while i < lhs.length
        left = lhs[i]
        right = lhs[i+1]
        i += 2

        if left.type == 'Keyword'
          switch left.toString()
            when 'keys'
              if right.type != 'Vector'
                throw 'Must be Vector rhs for :keys'

              for sym in right
                clauses.push pre.List(
                  pre.Symbol(assign)
                  sym
                  pre.List(
                    pre.Symbol('get')
                    rhs_id
                    pre.Literal(sym.name)
                  )
                )
            when 'as'
              if right.type != 'Symbol'
                throw 'Must be Symbol rhs for :as'

              clauses.push pre.List(
                pre.Symbol(assign)
                right
                rhs_id
              )

        else
          clauses.push pre.List(
            pre.Symbol(assign)
            left
            pre.List(
              pre.Symbol('get')
              rhs_id
              pre.Literal(right.toString())
            )
          )
    else
      clauses.push pre.List(pre.Symbol(assign), lhs, rhs)

  clauses

# JS creator

reduceBinaryOperator = (values, op) ->
  left = values[0]
  i = 1
  while i < values.length
    left = JS.BinaryExpression(left, op, values[i])
    i += 1
  left

id_counter = 0
nextID = -> ++id_counter

js_macros =
  fn: ({env, walker, scope}, args...) ->
    fn_args = args[0]

    lhss = []
    rhss = []
    formal_args = []
    c = 0

    new_scope = scope.newScope()

    for arg, i in fn_args
      if isKeyword(arg)
        throw "Can't have keywords as fn argument"
      else if isSymbol(arg)
        if arg.name == '&'
          lhss.push fn_args[i+1]
          rhss.push pre.List(reader.readString('Array.prototype.slice.call')[0], pre.Symbol('arguments'), pre.Literal(i))
          break
        else
          arg = walker(scope)(arg)
          new_scope.addSymbol arg.name, arg
          formal_args.push arg
      else
        id = pre.Symbol("arg$#{c}")
        formal_args.push id
        rhss.push id
        lhss.push arg

    fn_prelude = generateDestructuring(lhss, rhss).map(walker(new_scope))

    body = args.slice(1).map(walker(new_scope))

    if body.length == 0
      throw "Fn needs a body"

    body = fn_prelude.concat(body)

    ret_arg = body.pop()

    body = body.map (form) ->
      if form.type.match(/(Expression|Literal|Identifier)$/)
        JS.ExpressionStatement(form)
      else
        form

    if ret_arg.type.match(/Statement$/)
      throw 'Statement in last position of body'
      # body.push ret_arg
    else
      body.push JS.Return(ret_arg)

    JS.FunctionExpression(
      formal_args
      body
    )

  # Basic arithmetic

  '/': ({env, walker, scope}, args...) ->
    if args.length == 1
      JS.BinaryExpression(
        JS.Literal(1)
        "/"
        walker(scope)(args[0])
      )
    else
      reduceBinaryOperator(args.map(walker(scope)), '/')

  '+': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '+')

  '-': ({env, walker, scope}, args...) ->
    if args.length == 1
      JS.UnaryExpression '-', walker(scope)(args[0])
    else
      reduceBinaryOperator(args.map(walker(scope)), '-')

  '*': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '*')

  # boolean operators

  '>': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '>')

  '=': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '===')

  '!=': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '!==')

  '||': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '||')

  'or': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '||')

  '&&': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '&&')

  'and': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '&&')

  # bitwise operators

  # maybe consider something
  'bitwise-not': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '~')

  '^': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '^')

  '|': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '|')

  '&': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '&')

  '<<': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '<<')

  '>>': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '>>')

  '>>>': ({env, walker, scope}, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '>>>')

  # helper for member expressions

  '.': ({env, walker, scope}, callee, member, args...) ->
    walker = walker(scope)

    JS.CallExpression(
      JS.MemberExpression(walker(callee), walker(member))
      args.map(walker)
    )

  # syntax quote

  '`': ({env, walker, scope}, form) ->
    scope = scope.newScope()
    scope.quote()
    walker(scope)(form)

  jsmacro: ({env, walker, scope}, token, bindings, body...) ->
    macro_ast = walker(scope) pre.List.apply(null, [
      pre.Symbol('fn')
      bindings
      body...
    ])

    macro_js = codegen.generate(JS.ExpressionStatement macro_ast)

    fn = eval(macro_js)

    # console.log "jsmacro #{token.value}"
    # console.log macro_js
    # console.log "---"

    js_macros[token.value] = fn

    a = []
    a.$explode = true
    a

  'amap': ({env, walker, scope}, fn, arr) ->
    walker = walker(scope)

    JS.CallExpression(
      JS.MemberExpression(walker(arr), pre.Symbol('map'))
      [walker(fn)]
    )

  'macro': ({env, walker, scope}, args, body...) ->
    walker = walker(scope)

    walker(pre.List(
      reader.readString('terr$.Macro')[0]
      pre.List.apply null, [
        pre.Symbol('fn')
        args
        body...
      ]
    ))

  'get': ({env, walker, scope}, obj, key) ->
    walker = walker(scope)

    if !obj or !key
      throw 'get requires 2 arguments'

    if key.type == 'Keyword'
      key = pre.Literal(key.toString())

    JS.MemberExpressionComputed(walker(obj), walker(key))

  def: ({env, walker, scope}, id, value) ->
    id = walker(scope)(id)

    type: 'AssignmentExpression'
    operator: '='
    left:
      JS.MemberExpression(JS.Identifier('$env'), id)
    right:
      walker(scope)(value)

  'set!': ({env, walker, scope}, id, value) ->
    walker = walker(scope)

    type: 'AssignmentExpression'
    operator: '='
    left:
      walker(id)
    right:
      walker(value)

  do: ({env, walker, scope}, body...) ->
    walker = walker(scope.newScope())
    walker(pre.List(pre.List.apply(null, [pre.Symbol('fn'), pre.Vector(), body...])))

  for: ({env, walker, scope}, bindings, body...) ->
    if bindings.type != 'Vector'
      throw 'wrong let syntax'

    bindings = bindings

    if bindings.length % 2
      throw 'wrong number of args for for binding'

    i = bindings.length - 2
    right_form = null
    while i >= 0
      left = bindings[i]
      right = bindings[i+1]
      i -= 2

      inner_args = [
        pre.Symbol('fn')
        pre.Vector(pre.Symbol('for$arg'))
        generateDestructuring([left], [pre.Symbol('for$arg')])...
      ]

      if right_form == null
        inner_args = inner_args.concat(body)
      else
        inner_args.push right_form

      right_form = pre.List(
        reader.readString('terr$.For')[0]
        right
        pre.List.apply(null, inner_args)
        pre.Literal(right_form?)
      )

    walker(scope)(right_form)

  ns: ({env, walker, scope}, ns) ->
    env.ns$ = ns.value
    a = []
    a.$explode = true
    a

  require: ({env, walker, scope, statement}, bindings, use_kw) ->
    if bindings.type == 'Vector'
      if bindings.length % 2
        throw 'wrong number of args for let binding'

      names = []
      values = []
      for v, i in bindings
        if i % 2
          values.push v
        else
          names.push v

      values = values.map (dep_path) ->
        if dep_path.type != 'Literal'
          throw 'require paths must be string literals'

        munged = mungeSymbol(dep_path.value)

        env.requires$.push
          path: dep_path.value
          munged: munged

        return pre.Symbol(munged)

      destructuring = generateDestructuring(names, values, 'def')
      if statement
        r = walker(scope) destructuring
        r.$explode = true
        r
      else
        walker(scope) pre.List.apply(null, [pre.Symbol('do')].concat(destructuring, pre.Literal(null)))
    else if bindings.type == 'Literal'

      munged = null
      for req in env.requires$
        if req.path == bindings.value
          munged = req.munged
          break

      if !munged
        munged = mungeSymbol(bindings.value)
        env.requires$.push
          path: bindings.value
          munged: munged

      if isKeyword(use_kw) and use_kw.toString() == 'use'
        if statement
          walker(scope) pre.List(
            reader.readString('terr$.Copy')[0]
            pre.Symbol('$env')
            pre.Symbol(munged)
          )
        else
          JS.SequenceExpression([
            walker(scope) pre.List(
              reader.readString('terr$.Copy')[0]
              pre.Symbol('$env')
              pre.Symbol(munged)
            )
            walker(scope) pre.Symbol(munged)
          ])
      else
        walker(scope) pre.Symbol(munged)

  let: ({env, walker, scope}, bindings, body...) ->
    if bindings.type != 'Vector'
      throw 'wrong let syntax'

    if bindings.length % 2
      throw 'wrong number of args for let binding'

    names = []
    values = []
    for v, i in bindings
      if i % 2
        values.push v
      else
        names.push v

    fn_init = [pre.Symbol('fn'), pre.Vector(), generateDestructuring(names, values)...]

    scope = scope.newScope()

    walker(scope) pre.List(pre.List.apply(null, fn_init.concat(body)))

  var: ({env, walker, scope}, id, value) ->
    value = walker(scope)(value)

    name = mungeSymbol(id.name)
    id = JS.Identifier(name)

    if scope.resolve(name)
      id.name = "#{name}$#{nextID()}"

    scope.addSymbol(name, id)

    JS.VariableDeclaration [
      JS.VariableDeclarator(id, value)
    ]

  'if': ({env, walker, scope}, args...) ->
    walker = walker(scope)

    type: 'ConditionalExpression'
    test: walker(args[0])
    consequent: if args[1] then walker(args[1]) else pre.Literal(null)
    alternate: if args[2] then walker(args[2]) else pre.Literal(null)

isSymbol = (node) ->
  node.type == 'Symbol'

isKeyword = (node) ->
  typeof node == 'function' and node.type == 'Keyword'

mungeSymbol = (str) ->
  str.replace(/-/g, '_')
    .replace(/\:/g, "_COLON_")
    .replace(/\+/g, "_PLUS_")
    .replace(/\>/g, "_GT_")
    .replace(/\</g, "_LT_")
    .replace(/\=/g, "_EQ_")
    .replace(/\~/g, "_TILDE_")
    .replace(/\!/g, "_BANG_")
    .replace(/\@/g, "_CIRCA_")
    .replace(/\#/g, "_SHARP_")
    .replace(/\\'/g, "_SINGLEQUOTE_")
    .replace(/\"/g, "_DOUBLEQUOTE_")
    .replace(/\%/g, "_PERCENT_")
    .replace(/\^/g, "_CARET_")
    .replace(/\&/g, "_AMPERSAND_")
    .replace(/\*/g, "_STAR_")
    .replace(/\|/g, "_BAR_")
    .replace(/\{/g, "_LBRACE_")
    .replace(/\}/g, "_RBRACE_")
    .replace(/\[/g, "_LBRACK_")
    .replace(/\]/g, "_RBRACK_")
    .replace(/\//g, "_SLASH_")
    .replace(/\\/g, "_BSLASH_")
    .replace(/\?/g, "_QMARK_")
    .replace(/\./g, "_DOT_")

explodeSymbol = (s) ->
  parts = s.split(/\./g)

resolveSymbol = (s, env, scope) ->
  if scope.resolve(s)
    return null

  left = env
  for part in explodeSymbol(s)
    if !left[part]?
      return null

    left = left[part]

  left

analyseSymbol = (s, env, scope) ->
  if s != '.' and s.match(/\./)
    parts = explodeSymbol(s)

    root = parts[0]
    context = [root]
    rest = []

    i = 1
    while i < parts.length
      rest.push parts[i]
      i += 1

    constructor = rest[rest.length - 1]
    if constructor == ""
      rest.pop()

    context.pop()

    root: root
    rest: rest
    context_symbol: context.join('.')
    constructor: constructor
  else
    root: s
    rest: []
    context_symbol: null
    constructor: false

explodeArray = (args, scope, walker, typeFactory) ->

  if args.length == 0
    return JS.ArrayExpression([])

  arr_ptr = 0
  arr_expr = [ ]

  left = args[0]
  rest = args.slice(1)

  quoted = scope.quoted

  if quoted
    if left.$explode
      left = JS.CallExpression(
        JS.MemberExpression(
          typeFactory
          JS.Identifier('apply')
        )
        [pre.Literal(null)].concat(left)
      )
    else
      left = JS.CallExpression(
        typeFactory
        [left]
      )

    started_concat = false

    for right in rest
      if started_concat
        if right.$explode
          left.arguments.push right
        else
          left.arguments.push JS.ArrayExpression([right])
      else if right.$explode
        started_concat = true
        left = JS.CallExpression(
          terr$Concat
          [left, right]
        )
      else
        left.arguments.push right

  else
    if left.$explode
      left = left
    else
      left = JS.ArrayExpression([left])

    started_concat = false

    for right in rest
      if started_concat
        if right.$explode
          left.arguments.push right
        else if left.arguments[left.arguments.length - 1].type == 'ArrayExpression'
          left.arguments[left.arguments.length - 1].elements.push right
        else
          left.arguments.push JS.ArrayExpression([right])
      else if right.$explode or left.type != 'ArrayExpression'
        started_concat = true
        left = JS.CallExpression(
          JS.MemberExpression(
            left
            JS.Identifier('concat')
          )
          [right]
        )
      else
        left.elements.push right

  left

# Todo: resolve these automatically

envReference = (name) ->
  JS.MemberExpression(JS.Identifier('$env'), JS.Identifier(name))

terr$List = envReference('terr$.List')
terr$Symbol = envReference('terr$.Symbol')
terr$Keyword = envReference('terr$.Keyword')
terr$Vector = envReference('terr$.Vector')
terr$Literal = envReference('terr$.Literal')
terr$Concat = envReference('terr$.Concat')
terr$Macro = envReference('terr$.Macro')

TerribleToJsHandlers =
  List: (node, walker, context, scope) ->

    first = node[0]

    if scope.quoted and first?.name != '~'
      walker = walker(scope)

      exploded_list = explodeArray(node.slice(0).map(walker), scope, walker, terr$List)

      if exploded_list.type == 'CallExpression' and exploded_list.callee == terr$List
        return JS.CallExpression(terr$List, exploded_list.arguments)
      else
        return JS.CallExpression(
          JS.MemberExpression(terr$List, JS.Identifier('apply'))
          [pre.Literal(null), exploded_list]
        )

    if isSymbol(first) and macro = js_macros[first.name]
      return macro.apply(null, [{
        env: context
        walker
        scope
        statement: node.$statement
        JS
      }, node.slice(1)...])

    if isSymbol(first) and (r = resolveSymbol(mungeSymbol(first.name), context, scope)) and r.$macro
      args = node.slice(1)
      result = r.apply(null, args)
      walked = walker(scope)(result)
      return walked

    walker = walker(scope)

    if isKeyword(first)
      JS.MemberExpressionComputed(walker(node[1]), pre.Literal(first.toString()))
    else if isSymbol(first) or first.type == 'List'
      JS.CallExpression(walker(first), node.slice(1).map(walker))
    else
      JS.CallExpression(
        JS.MemberExpression(walker(first), pre.Symbol('call'))
        [pre.Literal(null)].concat(node.slice(1).map(walker))
      )

  Hash: (node, walker, context, scope) ->
    walker = walker(scope)

    props = []

    i = 0
    while i < node.length
      left = node[i]
      right = node[i+1]
      i += 2

      if isKeyword(left)
        left = JS.Literal(left.toString())
      else if left.type == 'Literal'
        left = left
      else
        throw 'non keyword/literal keys not yet supported'

      right = walker(right)

      props.push
        type: 'Property'
        key: left
        value: walker(right)
        kind: 'init'

    type: 'ObjectExpression'
    properties: props

  Vector: (node, walker, context, scope) ->
    walker = walker(scope)

    args = node.map(walker)

    explode_result = explodeArray(args, scope, walker, terr$Vector)

    ret = if explode_result.type == 'Vector'
      type: 'ArrayExpression'
      elements: explode_result
    else if scope.quoted
      explode_result
    else if explode_result.type == 'CallExpression' and explode_result.callee == terr$Vector
      type: 'ArrayExpression'
      elements: explode_result.arguments
    else
      explode_result

    ret

  Keyword: (node, walker, context, scope) ->
    JS.CallExpression(
      terr$Keyword
      [pre.Literal(node.toString())]
    )

  Literal: (node, walker, context, scope) ->
    if scope.quoted
      return JS.CallExpression(terr$Literal, [node])
    else
      node

  Symbol: (node, walker, context, scope) ->
    if scope.quoted
      return JS.CallExpression(terr$Symbol, [pre.Literal(node.name)])

    if isKeyword(node)
      JS.CallExpression(terr$Keyword, [pre.Literal(node.toString())])
    else if id = scope.resolve(node.name)
      id
    else if context[mungeSymbol(node.name)]?
      JS.MemberExpressionComputed(JS.Identifier('$env'), pre.Literal(mungeSymbol(node.name)))
    else
      JS.Identifier(mungeSymbol(node.name))

intoJS = (tree, context, scope, TOP_LEVEL) ->
  terribleWalker(TerribleToJsHandlers, context, tree, scope)


module.exports =
  asm: intoJS
  Scope: Scope
