import std/[tables, strutils], types, environment

proc createScope*(fun: KelpNode, xs: varargs[KelpNode]): KelpEnv =
  var data = initTable[string, KelpNode]()
  for i, e in fun.params.list:
    if e.str.startsWith('&'):
      if i == fun.params.list.high:
        data[e.str[1..^1]] = newList xs[i..^1]
      else:
        # this exception should really occur when the user is defining a function
        raise newException(ValueError, "only the last argument can be a vararg")
    else:
      data[e.str] = xs[i]
  newEnv(fun.env, data)
