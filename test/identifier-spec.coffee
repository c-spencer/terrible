r = new (require('./runner'))

r.get_env().a = [10, 20, 30]
r.get_env().b = {c: {d: 17}}
r.get_env().e = "d"

describe "Identifier member access", ->
  r.eval_expect "a", [10, 20, 30]
  r.eval_expect "a[0]", 10
  r.eval_expect "a[(+ 1 1)]", 30
  r.eval_expect "b.c", {d: 17}
  r.eval_expect "b.c.d", 17
  r.eval_expect "e", "d"
  r.eval_expect 'b.c[e]', 17
