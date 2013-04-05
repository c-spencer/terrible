optimist = require('optimist')

optimist = optimist.usage('Usage:')
  .options('c', {
    alias: 'compile'
    default: false
    type: 'boolean'
  })
  .options('h', {
    alias: 'help'
    default: false
    type: 'boolean'
  })

argv = optimist.argv

if argv.help
  optimist.showHelp()
  process.exit(0)

Environment = require('./environment')

if argv.compile
  null
else if argv._.length == 0 # start repl
  env = new Environment(__dirname + "/src/user")
  env.repl()
else
  target = argv._[0]
  env = Environment.fromFile(target)
  console.log env.js()
