# A partial port and modification of the Clojure reader
# https://github.com/clojure/clojure/blob/master/src/jvm/clojure/lang/LispReader.java

pre = require './prelude'

class Buffer
  constructor: (@string) ->
    @pos = 0

  read1: ->
    if @pos >= @string.length
      throw 'EOF while reading'

    ch = @string[@pos]
    ++@pos
    ch

  lookahead: (n) ->
    @string.substring(@pos, @pos + n)

  unread: (str) ->
    @pos -= str.length

symbolPattern = /^([:][^\d\s]|[^:\d\s])[^\n\t\r\s,]*$/

id_counter = 1

nextID = -> ++id_counter

gen_arg = (n) ->
  pre.Symbol((if n == -1 then "rest" else "arg$#{n}") + "__#{nextID()}#")

class Reader

  unmatchedDelimiter: (reader) ->
    throw "Unmatched delimiter"

  constructor: ->
    @macros =
      '"': @stringReader
      '(': @listReader
      ')': @unmatchedDelimiter
      '[': @vectorReader
      ']': @unmatchedDelimiter
      '{': @hashReader
      '}': @unmatchedDelimiter
      ';': @commentReader
      '#': @dispatchReader
      '%': @argReader
      '`': @syntaxQuoteReader
      '~': @unquoteReader
      '@': @splatReader

    @dispatch_macros =
      '(': @fnReader

  readString: (str, form_cb) ->
    buffer = new Buffer(str)
    forms = []
    while form = @read(buffer, true, true)
      forms.push form
    forms

  isWhitespace: (str) -> str.match(/[\t\r\n,\s]/)
  isDigit: (str) -> /^[0-9]$/.exec(str)
  isNumber: (n) -> !isNaN(parseFloat(n)) and isFinite(n)

  isTerminatingMacro: (ch) ->
    ch not in ['#', '\'', '%'] and @macros[ch]

  read: (buffer, recursive, silent=false) ->
    while true
      if silent
        try
          ch = buffer.read1()
          while @isWhitespace(ch)
            ch = buffer.read1()
        catch exc
          return null
      else
        ch = buffer.read1()
        while @isWhitespace(ch)
          ch = buffer.read1()

      if @isDigit(ch)
        return @readNumber(buffer, ch)

      if macro = @macros[ch]
        ret = macro(buffer, ch)
        if ret == buffer
          continue
        return ret

      if ch in ['+', '-']
        ch2 = buffer.read1()
        if @isDigit(ch2)
          n = @readNumber(buffer, ch2)
          return pre.List(pre.Symbol(ch), n)
        else
          buffer.unread(ch2)

      token = @readToken(buffer, ch)
      return @interpretToken(token)

  interpretToken: (s) ->
    if s in ['nil', 'null']
      return pre.Literal(null)
    if s == 'true'
      return pre.Literal(true)
    if s == false
      return pre.Literal(false)

    if symbol = @matchSymbol(s)
      return symbol

    throw "Invalid token: #{s}"

  matchSymbol: (s) ->
    if symbolPattern.exec(s)
      if s[0] == ":"
        return pre.Keyword(s.substring(1))
      else
        return pre.Symbol(s)
    else
      null

  readToken: (buffer, s) ->
    while true
      ch = buffer.read1()
      if @isWhitespace(ch) or @isTerminatingMacro(ch)
        buffer.unread(ch)
        return s
      s += ch

  readNumber: (buffer, s) ->
    while true
      ch = buffer.read1()
      if @isWhitespace(ch) or @macros[ch]
        buffer.unread(ch)
        break
      s += ch

    if !@isNumber(s)
      throw "Invalid number: #{s}"

    pre.Literal(parseFloat(s))

  readDelimitedList: (endchar, buffer, recursive) ->
    forms = []
    while true
      ch = buffer.read1()

      while @isWhitespace(ch)
        ch = buffer.read1()

      if ch == endchar
        break

      if macro = @macros[ch]
        ret = macro(buffer, ch)
        if ret != buffer
          forms.push(ret)
      else
        buffer.unread(ch)

        ret = @read(buffer, true)

        if ret != buffer
          forms.push ret

    forms

  listReader: (buffer, openparen) =>
    list = @readDelimitedList(')', buffer, true)
    if list[0].type == 'Symbol' and list[0].name.match(/[^\.]\.$/)
      pre.List.apply(null, [
        pre.Symbol('new')
        pre.Symbol(list[0].name.substring(0, list[0].name.length - 1))
        list.slice(1)...
      ])
    else
      pre.List.apply(null, list)

  vectorReader: (buffer, openparen) =>
    vector = @readDelimitedList(']', buffer, true)
    pre.Vector.apply(null, vector)

  hashReader: (buffer, openparen) =>
    hash = @readDelimitedList('}', buffer, true)
    if hash.length % 2
      throw "Hash must contain even number of forms"
    pre.Hash.apply(null, hash)

  commentReader: (buffer, openparen) =>
    ch = buffer.read1()
    while !ch.match(/[\n\r]/)
      ch = buffer.read1()
    buffer

  dispatchReader: (buffer, hash) =>
    ch = buffer.read1()
    @dispatch_macros[ch](buffer, ch)

  findArg: (n) ->
    for arg in @ARG_ENV
      if n == arg.n
        return arg

  registerArg: (n) ->
    if !@ARG_ENV
      throw "arg lit not in #()"

    symbol = @findArg(n)?.symbol
    if !symbol?
      symbol = gen_arg(n)
      @ARG_ENV.push {n, symbol}

    symbol

  argReader: (buffer, percent) =>
    if !@ARG_ENV
      return @interpretToken(@readToken(buffer, percent))

    ch = buffer.lookahead(1)

    if @isWhitespace(ch) or @isTerminatingMacro(ch)
      return @registerArg(1)

    n = @read(buffer, true)

    if n.type == 'Symbol' and n.name == '&'
      return @registerArg(-1)

    if n.type != 'Literal' or typeof n.value != 'number'
      throw 'arg literal must be %, %& or %n'

    return @registerArg(n.value)

  fnReader: (buffer, openparen) =>
    buffer.unread(openparen)

    @ARG_ENV = []

    form = @read(buffer, true)

    @ARG_ENV.sort (a, b) ->
      if a.n == -1
        1
      else if b.n == -1
        -1
      else
        a.n > b.n

    if @ARG_ENV[@ARG_ENV.length - 1].n == -1
      rest_arg = @ARG_ENV.pop().symbol
    else
      rest_arg = null

    args = []

    for prop, val of @ARG_ENV
      args[val.n-1] = val.symbol

    for i in [0...args.length]
      if !args[i]
        args[i] = gen_arg(i+1)

    arg_symbols = for prop, val of @ARG_ENV
      val.symbol

    if rest_arg
      args.push pre.Symbol('&')
      args.push rest_arg

    @ARG_ENV = null

    pre.List(pre.Symbol('fn'), args, form)

  syntaxQuoteReader: (buffer, tick) =>
    form = @read(buffer, true)
    pre.List(pre.Symbol('`'), form)

  unquoteReader: (buffer, tilde) =>
    form = @read(buffer, true)
    pre.List(pre.Symbol('~'), form)

  splatReader: (buffer, tilde) =>
    form = @read(buffer, true)
    pre.List(pre.Symbol('@'), form)

  stringReader: (buffer, quote) =>
    str = ""
    while (ch = buffer.read1()) != '"'
      if ch == "\\"
        ch = buffer.read1()

        switch ch
          when "t" then ch = "\t"
          when "r" then ch = "\r"
          when "n" then ch = "\n"
          when "b" then ch = "\b"
          when "f" then ch = "\f"
          when "\\" then null
          when '"' then null
          else throw "Unsupported escape \\#{ch}"

      str += ch

    pre.Literal(str)

module.exports = Reader
