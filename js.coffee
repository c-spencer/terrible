exports.Identifier = (name) ->
  type: 'Identifier'
  name: name

exports.CallExpression = (callee, args) ->
  type: 'CallExpression',
  callee: callee,
  arguments: args

exports.Block = (body) ->
  type: 'BlockStatement'
  body: body

exports.Return = (arg) ->
  type: 'ReturnStatement',
  argument: arg

exports.Function = (params, body) ->
  type: 'FunctionExpression'
  params: params
  body: exports.Block(body)

exports.ExpressionStatement = (expr) ->
  type: 'ExpressionStatement'
  expression: expr

exports.BinaryExpression = (left, operator, right) ->
  type: 'BinaryExpression'
  operator: operator
  left: left
  right: right

exports.MemberExpression = (object, property) ->
  type: 'MemberExpression'
  object: object
  property: property

exports.MemberExpressionComputed = (object, property) ->
  type: 'MemberExpression'
  object: object
  property: property
  computed: true
