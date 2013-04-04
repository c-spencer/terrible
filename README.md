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

A quick test run of an environment.

```javascript
var env = new Environment
env.eval(str)
console.log(env.js())
```

```clojure
(def inc (fn [x] (+ x 1)))

(inc 1)

(def splice (macro [& e] `(+ 4 5 ~@e 6 3)))

(splice 1 2)

[1 2 3 @body 4 5 6]

(def x 10)

(let [x x [a b] x] x)

(let [{a :a b :b} {:a 6 :b 7} y 15] (+ a b y))

(if (> 7 6)
  (do
    (console.log "All's \\" well")
    7)
  (do
    (console.log "Oh hum, numbers have broken.")
    6))
```

```javascript
$env.inc = function (x) {
    return x + 1;
};
$env.inc(1);
$env.splice = $env.terr$.Macro(function () {
    var e = $env.terr$.Slice.call(arguments, 0);
    return $env.terr$.List.apply(null, $env.terr$.Concat($env.terr$.List($env.terr$.Symbol('+'), $env.terr$.Literal(4), $env.terr$.Literal(5)), e, [$env.terr$.Literal(6)], [$env.terr$.Literal(3)]));
});
4 + 5 + 1 + 2 + 6 + 3;
[
    1,
    2,
    3
].concat(body, [
    4,
    5,
    6
]);
$env.x = 10;
(function () {
    var x = $env.x;
    var a = x[0];
    var b = x[1];
    return x;
}.call(null));
(function () {
    var $rhs = {
            a: 6,
            b: 7
        };
    var a = $rhs.a;
    var b = $rhs.b;
    var y = 15;
    return a + b + y;
}.call(null));
7 > 6 ? function () {
    console.log('All\'s " well');
    return 7;
}.call(null) : function () {
    console.log('Oh hum, numbers have broken.');
    return 6;
}.call(null);
```
