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
  .options('j', {
    alias: 'js'
    default: false
    type: 'boolean'
  })
  .options('r', {
    alias: 'read'
    default: false
    type: 'boolean'
  })

argv = optimist.argv

print = (args...) -> console.log require('util').inspect(args, false, 20)

if argv.help
  optimist.showHelp()
  process.exit(0)
else if argv.read
  Reader = require './reader'
  reader = new Reader()
  console.log 'reading', argv._[0]
  print reader.readString(argv._[0])
  process.exit(0)

# Load project configuration

Environment = require('./environment')
project_env = Environment.fromFile('project.trbl')

default_settings =
  "src-directory": "src2"

project_settings = project_env.context.env.project

for k, v of project_settings
  default_settings[k] = v

project_settings = default_settings

# Do task

if argv._.length == 0 # start repl
  env = new Environment(__dirname + "/#{project_settings['src-directory']}/user")
  env.repl()
else
  target = argv._[0]

  if argv.js
    env = Environment.fromFile(target)
    console.log env.js()
  else if argv.compile
    env = Environment.fromFile(target)
    env.js(compile: true)
  else
    env = Environment.fromFile(target)
    env.repl()
