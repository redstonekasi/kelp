import std/[tables, strutils], types, environment

proc createScope*(fun: KelpNode, xs: varargs[KelpNode]): KelpEnv =
  var data = initTable[string, KelpNode]()
  if fun.isHash:
    for i, a in xs:
      data["$" & $(i + 1)] = a
    data["$&"] = newList xs
    if xs.len > 0: data["$"] = xs[0]
  else:
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
