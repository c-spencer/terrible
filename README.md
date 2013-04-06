# Terrible Programming Language

Terrible is a looks-like-clojure, smells-like-javascript language that aims to be a fairly thin wrapper over javascript, but with some of the nice bits of clojure, as well as a few others.

Done:
- Javascript accessors mixed with clojure-y syntax `(set! a[(+ 1 2)] 10)`
- Compilation out to striaght javascript, minimal obfuscation

WIP:
- Module system integration (generates UMD, works in node, not yet browser)

Todo:
- Self hosting
- Optional reader, for runtime macros and reading

## Usage

This is mostly an experiment for fun and learning a bit more about compilers and runtime environments. It would be a Terrible Idea to use this for anything serious.

## Examples

A quick test run of an environment.

```clojure
(ns "trbl/demo")

(defn inc [x] (+ x 1))

(inc 1)

(defmacro splice [& e] `(+ 4 5 ~@e 6 3))

(splice 1 2)

[1 2 3 @body 4 5 6]

(def x 10)
(def my-key "a")
(def my-map {:a 6 :b 7})

(set! my-map[my-key] 8)

(let [x x [a b] x] x)

(let [{a :a b :b} {:a 6 :b 7} y 15] (+ a b y))

(if (> 7 6)
  (do
    (console.log "All's \" well")
    7)
  (do
    (console.log "Oh hum, numbers have broken.")
    6))
```

```javascript
(function (root, factory) {
    if (typeof exports === 'object') {
        module.exports = factory(require('..\\coffee\\prelude'), require('./core'));
    } else if (typeof define === 'function' && define.amd) {
        define([
            'coffee/prelude',
            'trbl!trbl/core'
        ], factory);
    } else {
        root['trbl/demo'] = factory(root['coffee/prelude'], root['trbl/core']);
    }
}(this, function (coffee_SLASH_prelude, trbl_BANG_trbl_SLASH_core) {
    var $env = {};
    $env.terr$ = coffee_SLASH_prelude;
    $env.terr$.Copy($env, trbl_BANG_trbl_SLASH_core);
    $env.inc = function (x) {
        return x + 1;
    };
    $env.inc(1);
    $env.splice = $env.terr$.Macro(function () {
        var e = Array.prototype.slice.call(arguments, 0);
        return $env.terr$.List.apply(null, $env.terr$.Concat($env.terr$.List($env.terr$.Symbol('+'), $env.terr$.Literal(4), $env.terr$.Literal(5)), e, [$env.terr$.Literal(6)], [$env.terr$.Literal(3)])
);
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
    $env.my_key = 'a';
    $env.my_map = {
        'a': 6,
        'b': 7
    };
    $env.my_map[$env.my_key] = 8;
    (function () {
        var x = $env.x;
        var a = x[0];
        var b = x[1];
        return x;
    }());
    (function () {
        var $rhs = {
                'a': 6,
                'b': 7
            };
        var a = $rhs.a;
        var b = $rhs.b;
        var y = 15;
        return a + b + y;
    }());
    7 > 6 ? function () {
        console.log('All\'s " well');
        return 7;
    }() : function () {
        console.log('Oh hum, numbers have broken.');
        return 6;
    }();
    return $env;
}));
```
