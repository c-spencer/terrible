Environment = require "../src/coffee/environment"

class Runner
  constructor: ->
    @env = new Environment()
    @env.filepath = __dirname + "/../src/testrunner"
    @env.set_ns("testrunner")

  eval_expect: (str, res) =>
    it str, =>
      expect(@env.eval(str)).toEqual(res)

module.exports = Runner
