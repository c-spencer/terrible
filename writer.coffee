terribleWalker = require('./walker')
pre = require './prelude'
JS = require './js'

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


generateDestructuring = (lhss, rhss) ->
  clauses = []

  for lhs, i in lhss
    rhs = rhss[i]
    if lhs.type == 'Vector'
      if rhs.type == 'Symbol'
        rhs_id = rhs
      else
        rhs_id = pre.Symbol('$rhs')
        clauses.push pre.List(pre.Symbol('var'), rhs_id, rhs)

      for ident, i in lhs
        clauses.push pre.List(
          pre.Symbol('var')
          ident
          pre.List(pre.Symbol('get'), rhs_id, pre.Literal(i))
        )
    else if lhs.type == 'Hash'

      if rhs.type == 'Symbol'
        rhs_id = rhs
      else
        rhs_id = pre.Symbol('$rhs')
        clauses.push pre.List(pre.Symbol('var'), rhs_id, rhs)

      i = 0
      while i < lhs.length
        left = lhs[i]
        right = lhs[i+1]
        i += 2

        clauses.push pre.List(
          pre.Symbol('var')
          left
          pre.List(
            pre.Symbol('get')
            rhs_id
            pre.Literal(right.toString())
          )
        )
    else
      clauses.push pre.List(pre.Symbol('var'), lhs, rhs)

  clauses

# JS creator

reduceBinaryOperator = (values, op) ->
  left = values[0]
  i = 1
  while i < values.length
    left = JS.BinaryExpression(left, op, values[i])
    i += 1
  left

js_macros =
  fn: (walker, scope, args...) ->
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
          rhss.push pre.List(pre.Symbol('terr$.Slice.call'), pre.Symbol('arguments'), pre.Literal(i))
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

    body = args.slice(1).map(walker(new_scope))

    body = generateDestructuring(lhss, rhss).map(walker(new_scope)).concat(body)

    ret_arg = body.pop()

    body = body.map (form) ->
      if form.type.match(/(Expression|Literal)$/)
        JS.ExpressionStatement(form)
      else
        form

    body.push JS.Return(ret_arg)

    JS.Function(
      formal_args
      body
    )

  'new': (walker, scope, callee, args...) ->
    walker = walker(scope)

    type: 'NewExpression'
    callee: walker(callee)
    arguments: args.map(walker)

  '/': (walker, scope, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '/')

  '+': (walker, scope, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '+')

  '-': (walker, scope, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '-')

  '*': (walker, scope, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '*')

  '>': (walker, scope, args...) ->
    reduceBinaryOperator(args.map(walker(scope)), '>')

  '.': (walker, scope, callee, member, args...) ->
    walker = walker(scope)

    JS.CallExpression(
      JS.MemberExpression(walker(callee), walker(member))
      args.map(walker)
    )

  '`': (walker, scope, form) ->
    scope = scope.newScope()
    scope.quote()
    walker(scope)(form)

  '~': (walker, scope, form) ->
    scope = scope.newScope()
    scope.unquote()
    walker(scope)(form)

  '@': (walker, scope, form) ->
    form = walker(scope)(form)
    form.$explode = true
    form

  'amap': (walker, scope, fn, arr) ->
    walker = walker(scope)

    JS.CallExpression(
      JS.MemberExpression(walker(fn), Symbol('map'))
      [walker(arr)]
    )

  'macro': (walker, scope, args, body...) ->
    walker = walker(scope)

    walker(pre.List(
      pre.Symbol('terr$.Macro')
      pre.List.apply null, [
        pre.Symbol('fn')
        args
        body...
      ]
    ))

  'get': (walker, scope, obj, key) ->
    walker = walker(scope)

    JS.MemberExpressionComputed(walker(obj), walker(key))

  def: (walker, scope, id, value) ->
    id = walker(scope)(id)

    type: 'ExpressionStatement'
    expression:
      type: 'AssignmentExpression'
      operator: '='
      left:
        JS.MemberExpression(JS.Identifier('$env'), id)
      right:
        walker(scope)(value)

  'set!': (walker, scope, id, value) ->
    walker = walker(scope)

    type: 'AssignmentExpression'
    operator: '='
    left:
      walker(id)
    right:
      walker(value)

  do: (walker, scope, body...) ->
    walker = walker(scope.newScope())
    walker(pre.List(pre.List.apply(null, [pre.Symbol('fn'), pre.Vector(), body...])))

  let: (walker, scope, bindings, body...) ->
    if bindings.type != 'Vector'
      throw 'wrong let syntax'

    bindings = bindings

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

  var: (walker, scope, id, value) ->
    id = JS.Identifier(id.name)

    value = walker(scope)(value)

    scope.addSymbol(id.name, id)

    type: 'VariableDeclaration'
    declarations: [
      type: 'VariableDeclarator'
      id: id
      init: value
    ]
    kind: 'var'

  'if': (walker, scope, args...) ->
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

quoteCall = (context, quoted, fn) ->
  currently_quoted = context.quoted
  context.quoted = quoted
  result = fn()
  context.quoted = currently_quoted
  return result

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

explodeArray = (args, scope, walker, typeFactory) ->
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
          left.arguments.push {type: 'ArrayExpression', elements: [right]}
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
      left = {
        type: 'ArrayExpression'
        elements: [left]
      }

    started_concat = false

    for right in rest
      if started_concat
        if right.$explode
          left.arguments.push right
        else if left.arguments[left.arguments.length - 1].type == 'ArrayExpression'
          left.arguments[left.arguments.length - 1].elements.push right
        else
          left.arguments.push {type: 'ArrayExpression', elements: [right]}
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
      return macro.apply(null, [walker, scope, node.slice(1)...])

    if isSymbol(first) and (r = resolveSymbol(first.name, context, scope)) and r.$macro
      args = node.slice(1)
      result = r.apply(null, args)
      walked = walker(scope)(result)
      return walked

    walker = walker(scope)

    if isKeyword(first)
      JS.MemberExpressionComputed(walker(node[1]), pre.Literal(first.toString()))
    else if isSymbol(first)
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
        left = pre.Symbol(left.toString())
      else if left.type == 'Literal'
        left = left
      else
        throw 'non keyword/literal keys not yet supported'

      right = walker(right)

      props.push
        type: 'Property'
        key: walker(left)
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

  Program: (node, walker, context, scope) ->
    walker = walker(scope)

    type: 'Program'
    body: node.body.map(walker).map (tlnode) ->
      if tlnode.type.match(/Expression$/)
        JS.ExpressionStatement(tlnode)
      else
        tlnode

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
    else if node.name != '.' and node.name.match(/\./)
      parts = node.name.split(/\./g)

      # check if we're an initialiser
      if parts[parts.length - 1] == ""
        parts.pop()

      root = parts[0]

      if context[root]
        left = JS.MemberExpressionComputed(JS.Identifier('$env'), pre.Literal(root))
      else
        left = JS.Identifier(root)

      i = 1
      while i < parts.length
        left = JS.MemberExpression(left, JS.Identifier(parts[i]))
        i += 1
      left
    else if id = scope.resolve(node.name)
      JS.Identifier(mungeSymbol(node.name))
    else if context[node.name]
      JS.MemberExpressionComputed(JS.Identifier('$env'), pre.Literal(node.name))
    else
      JS.Identifier(mungeSymbol(node.name))

intoJS = (tree, context, scope) ->
  terribleWalker(TerribleToJsHandlers, context, tree, scope)

module.exports =
  asm: intoJS
  Scope: Scope
