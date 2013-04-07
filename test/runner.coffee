Environment = require "../src/coffee/environment"

class Runner
  constructor: ->
    @env = new Environment()
    @env.filepath = __dirname + "/../src/testrunner"
    @env.set_ns("testrunner")

  eval_expect: (str, res) =>
    it str, =>
      expect(@env.eval(str, true)).toEqual(res)

  eval: (str) =>
    @env.eval(str, true)

  get_env: =>
    @env.context.env

module.exports = Runner
