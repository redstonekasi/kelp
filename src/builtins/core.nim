import std/[sequtils, strutils, tables], ../types, ../printer, ../eval, ../util

# in a seperate module due to circular dependencies, this shouldn't really be here
proc execute*(x: KelpNode, args: varargs[KelpNode]): KelpNode =
  case x.kind
  of kpNative: x.fun(args)
  of kpFun:
    if args.len < x.params.list.len:
      raise newException(ValueError, "insufficient amount of arguments, expected $1, got $2" % [$x.params.list.len, $args.len])

    var scope = createScope(x, args)

    x.body.eval(scope)
  else: raise newException(ValueError, "you can only execute functions")

template wrapNumericOperator(op: untyped, init = 0): untyped =
  newNative proc(xs: varargs[KelpNode]): KelpNode =
    if not xs.allIt(it.isNumber):
      raise newException(ValueError, "expected number as argument")
    if xs.len > 1:
      newNumber xs[1..^1].foldl(op(a, b.number), xs[0].number)
    else:
      newNumber xs.foldl(op(a, b.number), BiggestInt(init))

template wrapComparisonOperator(op): untyped =
  newNative proc(xs: varargs[KelpNode]): KelpNode =
    if xs.len < 2:
      raise newException(ValueError, "unexpected number of arguments, expected 2, got " & $xs.len)
    if not xs.allIt(it.isNumber):
      raise newException(ValueError, "expected number as argument")
    if op(xs[0].number, xs[1].number): trueObj else: falseObj

template wrapTypeNative(op): untyped =
  newNative proc(xs: varargs[KelpNode]): KelpNode =
    if xs.len < 1:
      raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
    boolObj op(xs[0])

proc equal(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected 2, got " & $xs.len)
  boolObj xs[0] == xs[1]

proc andBool(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected at least 1, got " & $xs.len)
  boolObj xs.allIt(it.kind notin {kpNil, kpFalse})

proc orBool(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected at least 1, got " & $xs.len)
  boolObj xs.anyIt(it.kind notin {kpNil, kpFalse})

proc length(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  case xs[0].kind:
  of kpSymbol, kpString: newNumber xs[0].str.len
  of kpList, kpVector: newNumber xs[0].list.len
  else: newNumber 0

proc empty(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  case xs[0].kind:
  of kpSymbol, kpString: boolObj xs[0].str.len == 0
  of kpList, kpVector: boolObj xs[0].list.len == 0
  else: falseObj

proc nth(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected 2, got " & $xs.len)
  if not xs[0].isSequential:
    raise newException(ValueError, "expected list or vector as first argument")
  if not xs[1].isNumber:
    raise newException(ValueError, "expected number as second argument")
  if xs[1].number < xs[0].list.len: return xs[0].list[xs[1].number]
  else: raise newException(ValueError, "index out of range")

proc slice(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 3:
    raise newException(ValueError, "unexpected number of arguments, expected 3, got " & $xs.len)
  if not xs[0].isSequential:
    raise newException(ValueError, "expected list or vector as first argument")
  if not (xs[1].isNumber and xs[2].isNumber):
    raise newException(ValueError, "expected number as second and third argument")
  if xs[1].number > xs[2].number:
    raise newException(ValueError, "start of range cannot be larger than end")
  if xs[1].number < 0 or xs[2].number >= xs[0].list.len:
    raise newException(ValueError, "range out of bounds")

  let newRes = if xs[0].isList: newList else: newVector
  newRes xs[0].list[xs[1].number .. xs[2].number]

proc unshift(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected 2, got " & $xs.len)
  if not xs[0].isSequential:
    raise newException(ValueError, "expected list or vector as first argument")
  let newRes = if xs[0].isList: newList else: newVector
  result = newRes xs[0].list
  result.list.insert xs[1]

proc concat(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected at least 1, got " & $xs.len)
  if not xs.allIt(it.isSequential):
    raise newException(ValueError, "expected list or vector as argument")

  let newRes = if xs[0].isList: newList else: newVector
  result = newRes()
  for l in xs: result.list.add l.list

proc map(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected 2, got " & $xs.len)
  if not xs[0].isSequential:
    raise newException(ValueError, "expected list or vector as first argument")
  if xs[1].kind notin {kpNative, kpFun}:
    raise newException(ValueError, "expected function as second argument")

  let newRes = if xs[0].isList: newList else: newVector
  newRes xs[0].list.mapIt(xs[1].execute(it))

proc keys(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  if not xs[0].isTable:
    raise newException(ValueError, "expected table as argument")

  result = newList()
  for key in xs[0].table.keys: result.list.add newKeyword(key)

proc values(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  if not xs[0].isTable:
    raise newException(ValueError, "expected table as argument")

  newList xs[0].table.values.toSeq

proc assoc(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected 2, got " & $xs.len)
  if not xs.allIt(it.isTable):
    raise newException(ValueError, "expected table as argument")

  result = newTable(xs[0].table)
  for key, val in xs[1].table:
    result.table[key] = val

proc dissoc(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected 2, got " & $xs.len)
  if not xs[0].isTable:
    raise newException(ValueError, "expected table as first argument")
  if not xs[1..^1].allIt(it.isKeyword):
    raise newException(ValueError, "expected keywords as rest of the arguments")

  result = newTable(xs[0].table)
  for k in xs[1..^1]:
    result.table.del(k.str)

proc has(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected 2, got " & $xs.len)
  if xs[0].kind notin {kpList, kpVector, kpTable}:
    raise newException(ValueError, "expected list, vector or table as first argument")
  if xs[0].isTable and not xs[1].isKeyword:
    raise newException(ValueError, "expected keyword as second argument for table")

  if xs[0].isSequential:
    boolObj xs[0].list.anyIt(it == xs[1])
  else:
    boolObj xs[0].table.hasKey(xs[1].str)

proc call(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected at least 2, got " & $xs.len)
  if xs[0].kind notin {kpNative, kpFun}:
    raise newException(ValueError, "expected function as first argument")
  if not xs[^1].isSequential:
    raise newException(ValueError, "expected list or vector as last argument")

  var args = newSeq[KelpNode]()
  if xs.len > 2:
    args.add xs[1..^2]
  args.add xs[^1].list
  xs[0].execute(args)

proc toString(xs: varargs[KelpNode]): KelpNode =
  newString xs.mapIt(`$`(it, false)).join()

proc symbol(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  if not xs[0].isString:
    raise newException(ValueError, "expected string as argument")
  newSymbol xs[0].str

proc keyword(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  if not xs[0].isString:
    raise newException(ValueError, "expected string as argument")
  newKeyword xs[0].str

proc atom(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  newAtom xs[0]

proc deref(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  if not xs[0].isAtom:
    raise newException(ValueError, "expected atom as argument")
  xs[0].val

proc assign(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected 2, got " & $xs.len)
  if not xs[0].isAtom:
    raise newException(ValueError, "expected atom as first argument")
  # if xs[1].isAtom:
  #   raise newException(ValueError, "cannot assign atom to atom")
  xs[0].val = xs[1]
  xs[0].val

proc apply(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 2:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  if not xs[0].isAtom:
    raise newException(ValueError, "expected atom as first argument")
  if xs[1].kind notin {kpNative, kpFun}:
    raise newException(ValueError, "expected function as second argument")

  let res = xs[1].execute(xs[0].val)
  # if res.isAtom:
  #   raise newException(ValueError, "cannot assign atom to atom")
  xs[0].val = res
  res

let coreNamespace* = {
  "+": wrapNumericOperator `+`, # math operators
  "-": wrapNumericOperator `-`,
  "*": wrapNumericOperator(`*`, 1),
  "%": wrapNumericOperator(`mod`, 1),
  "/": wrapNumericOperator(`div`, 1), # i don't have floating point numbers yet

  "<": wrapComparisonOperator(`<`), # comparison operators
  ">": wrapComparisonOperator(`>`),
  "<=": wrapComparisonOperator(`<=`),
  ">=": wrapComparisonOperator(`>=`),
  "=": newNative equal,

  "and": newNative andBool,
  "or": newNative orBool,
  "not": wrapTypeNative isFalse,

  "len": newNative length, # list / vector functions
  "empty?": newNative empty,
  "nth": newNative nth,
  "slice": newNative slice,
  "unshift": newNative unshift,
  "concat": newNative concat,
  "map": newNative map,

  "keys": newNative keys, # table functions
  "values": newNative values,
  "assoc": newNative assoc,
  "dissoc": newNative dissoc,

  "has?": newNative has,
  "call": newNative call,
  "string": newNative toString,

  "symbol": newNative symbol, # instantiation functions
  "keyword": newNative keyword,
  "list": newNative newList,
  "vector": newNative newVector,
  "atom": newNative atom,

  "deref": newNative deref, # atom functions
  "assign!": newNative assign,
  "apply!": newNative apply,

  "nil?": wrapTypeNative isNil, # type check functions
  "true?": wrapTypeNative isTrue,
  "false?": wrapTypeNative isFalse,
  "number?": wrapTypeNative isNumber,
  "symbol?": wrapTypeNative isSymbol,
  "keyword?": wrapTypeNative isKeyword,
  "string?": wrapTypeNative isString,
  "list?": wrapTypeNative isList,
  "vector?": wrapTypeNative isVector,
  "table?": wrapTypeNative isTable,
  "native?": wrapTypeNative isNative,
  "fun?": wrapTypeNative isFun,
  "atom?": wrapTypeNative isAtom,
  "sequential?": wrapTypeNative isSequential,
}.toTable
