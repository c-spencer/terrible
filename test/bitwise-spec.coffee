r = new (require('./runner'))

describe "Bitwise or", ->
  r.eval_expect "(| 1 2)", 3
  r.eval_expect "(| 1)", 1
  r.eval_expect "(| 1 3)", 3

describe "Bitwise not", ->
  r.eval_expect "(bitwise-not 0)", -1
  r.eval_expect "(bitwise-not 1)", -2

describe "Bitwise xor", ->
  r.eval_expect "(^ 1 3)", 2

describe "Bitwise and", ->
  r.eval_expect "(& 1 2)", 0
  r.eval_expect "(& 1 1)", 1

describe "Bitwise >>", ->
  r.eval_expect "(>> 4 2)", 1

describe "Bitwise <<", ->
  r.eval_expect "(<< 1 2)", 4

describe "Bitwise <<<", ->
  r.eval_expect "(>>> -1 0)", 4294967295
