# Constructors and helpers

exports.Literal = (val) -> { type: 'Literal', value: val }
exports.Symbol = (val) -> { type: 'Symbol', name: val }
exports.List = (args...) ->
  args.type = 'List'
  args
exports.Vector = (args...) ->
  args.type = 'Vector'
  args
exports.Hash = (args...) ->
  args.type = 'Hash'
  args
exports.Keyword = (name) ->
  kw = (m) ->
    return m[name]

  kw.toString = -> name
  kw.type = 'Keyword'
  kw
exports.Macro = (fn) ->
  fn.$macro = true
  fn
exports.Concat = (left, right...) ->
  r = left.concat.apply(left, right)
  r.type = left.type
  r
exports.Slice = [].slice
exports['+'] = (left, rest...) ->
  for arg in rest
    left += arg
  left
exports.For = (iteratee, body, concat=false) ->
  result = []
  if iteratee instanceof Array
    for i in iteratee
      if concat
        result.push.apply(result, body(i))
      else
        result.push body(i)
  else
    for k, v of iteratee
      if concat
        result.push.apply(result, body([k, v]))
      else
        result.push body([k, v])
  result

exports.Copy = (target, source) ->
  for k, v of source
    if !~k.indexOf('$')
      target[k] = v
  target
