# Terrible Programming Language

Terrible is a looks-like-clojure, smells-like-javascript language that aims to be a fairly thin wrapper over javascript, but with some of the nice bits of clojure, as well as a few others.

Goals:
- Self hosting
- Optional reader, for runtime macros and reading
- AOT compilation without a runtime
- Some module system integration, AMD and CommonJS, or whatever is in vogue.

## Usage

This is mostly an experiment for fun and learning a bit more about compilers and runtime environments. It would be a Terrible Idea to use this for anything serious.

## Examples

A few quick pastes from test code. Things such as ensuring all forms are expressions and optimal generation are yet to do.

```clojure
(def inc (fn [x] (+ x 1)))
```

```javascript
$env.inc = function (x) {
    return x + 1;
};
```

```clojure
(inc 1)
```

```javascript
return $env['inc'](1);
```

```clojure
(def twice (macro [& e] `(+ 4 5 ~@e 6 3))))
```

```javascript
$env.twice = $env['terr$'].Macro(function () {
    var e = $env['terr$'].Slice.call(arguments, 0);
    return $env.terr$.List.apply(null, $env.terr$.Concat($env.terr$.List($env.terr$.Symbol('+'), $env.terr$.Literal(4), $env.terr$.Literal(5)), e, [$env.terr$.Literal(6)], [$env.terr$.Literal(3)]));
});
```

```clojure
terrible> (twice 1 2)
```

```javascript
return 4 + 5 + 1 + 2 + 6 + 3;
```

```clojure
terrible> [1 2 3 @body 4 5 6]
```

```javascript
return [
    1,
    2,
    3
].concat(body, [
    4,
    5,
    6
]);
```

```clojure
terrible> (def x 10)
```

```javascript
$env.x = 10;
```

```clojure
(let [{a :a b :b} {:a 6 :b 7} y 15] (+ a b y))
```

```javascript
return function () {
    var $rhs = {
            a: 6,
            b: 7
        };
    var a = $rhs['a'];
    var b = $rhs['b'];
    var y = 15;
    return a + b + y;
}.call(null);
```
