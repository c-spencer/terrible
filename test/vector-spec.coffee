r = new (require('./runner'))

describe "definition", ->
  r.eval_expect "[1 2 3]", [1, 2, 3]

describe "splats"
  r.eval_expect "[1 2 3 @[4 5]]", [1, 2, 3, 4, 5]
