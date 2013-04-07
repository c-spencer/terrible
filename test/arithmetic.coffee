Environment = require "../src/coffee/environment"

env = new Environment()
env.filepath = __dirname + "/../src/testrunner"
env.set_ns("testrunner")

eval_expect = (str, res) ->
  it str, ->
    expect(env.eval(str)).toBe(res)

describe "Addition", ->
  eval_expect "(+ 2)", 2
  eval_expect "(+ 1 2)", 3
  eval_expect "(+ 1 2 3)", 6
  eval_expect "(+ -1 -2)", -3
  eval_expect "(+ +1 -2)", -1

describe "Subtraction", ->
  eval_expect "(- 1)", -1
  eval_expect "(- +2 -1)", 3
  eval_expect "(- 1 2 3)", -4

describe "Multiplication", ->
  eval_expect "(* 8)", 8
  eval_expect "(* -2 +8)", -16
  eval_expect "(* 2 3 4)", 24

describe "Divison", ->
  eval_expect "(/ 2)", 0.5
  eval_expect "(/ 4 2)", 2
  eval_expect "(/ 4 2 2)", 1

describe "Expontiation", ->
  eval_expect "(** 2)", 2
  eval_expect "(** 2 3)", 8
  eval_expect "(** 2 0)", 1
  eval_expect "(** 2 3 2)", 64


describe "Bitwise or", ->
  eval_expect "(| 1 2)", 3
  eval_expect "(| 1)", 1
  eval_expect "(| 1 3)", 3

describe "Bitwise not", ->
  eval_expect "(bitwise-not 0)", -1
  eval_expect "(bitwise-not 1)", -2

describe "Bitwise xor", ->
  eval_expect "(^ 1 3)", 2

describe "Bitwise and", ->
  eval_expect "(& 1 2)", 0
  eval_expect "(& 1 1)", 1

describe "Bitwise >>", ->
  eval_expect "(>> 4 2)", 1

describe "Bitwise <<", ->
  eval_expect "(<< 1 2)", 4

describe "Bitwise <<<", ->
  eval_expect "(>>> -1 0)", 4294967295
