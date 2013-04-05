exports.Identifier = (name) ->
  type: 'Identifier'
  name: name

exports.Literal = (value) ->
  type: 'Literal'
  value: value

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

exports.FunctionExpression = (params, body) ->
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

exports.IfStatement = (test, consequent, alternate) ->
  type: 'IfStatement'
  test: test
  consequent: consequent
  alternate: alternate

exports.UnaryExpression = (operator, argument) ->
  type: 'UnaryExpression'
  operator: operator
  argument: argument

exports.MemberExpression = (object, property) ->
  type: 'MemberExpression'
  object: object
  property: property

exports.LogicalExpression = (left, operator, right) ->
  type: 'LogicalExpression'
  operator: operator
  left: left
  right: right

exports.AssignmentExpression = (left, operator, right) ->
  type: 'AssignmentExpression'
  operator: operator
  left: left
  right: right

exports.ArrayExpression = (elements) ->
  type: 'ArrayExpression'
  elements: elements

exports.Program = (body) ->
  type: 'Program'
  body: body

exports.MemberExpressionComputed = (object, property) ->
  if property.type == 'Literal' and /^[a-zA-Z_$][0-9a-zA-Z_$]*$/.exec(property.value)
    property = exports.Identifier(property.value)
    computed = false
  else
    computed = true

  type: 'MemberExpression'
  object: object
  property: property
  computed: computed
