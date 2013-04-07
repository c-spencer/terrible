r = new (require('./runner'))

describe "Addition", ->
  r.eval_expect "(+ 2)", 2
  r.eval_expect "(+ 1 2)", 3
  r.eval_expect "(+ 1 2 3)", 6
  r.eval_expect "(+ -1 -2)", -3
  r.eval_expect "(+ +1 -2)", -1

describe "Subtraction", ->
  r.eval_expect "(- 1)", -1
  r.eval_expect "(- +2 -1)", 3
  r.eval_expect "(- 1 2 3)", -4

describe "Multiplication", ->
  r.eval_expect "(* 8)", 8
  r.eval_expect "(* -2 +8)", -16
  r.eval_expect "(* 2 3 4)", 24

describe "Divison", ->
  r.eval_expect "(/ 2)", 0.5
  r.eval_expect "(/ 4 2)", 2
  r.eval_expect "(/ 4 2 2)", 1

describe "Expontiation", ->
  r.eval_expect "(** 2)", 2
  r.eval_expect "(** 2 3)", 8
  r.eval_expect "(** 2 0)", 1
  r.eval_expect "(** 2 3 2)", 64
