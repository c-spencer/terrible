r = new (require('./runner'))

describe "Vector definition", ->
  r.eval_expect "[]", []
  r.eval_expect "[1 2 3]", [1, 2, 3]

describe "Vector splats", ->
  r.eval_expect "[1 2 3 @[4 5]]", [1, 2, 3, 4, 5]
