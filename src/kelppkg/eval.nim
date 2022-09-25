import std/[tables, sequtils, strutils], environment, types, util, printer

type EvalError = object of ValueError

const SpecialForms = ["def!", "let*", "fn*", "defn!", "do", "if", "quote", "quasiquote", "unquote", "splice-unquote", "defmacro!", "hashfn"]

proc quasiquote(node: KelpNode): KelpNode

proc quasiloop(xs: seq[KelpNode]): KelpNode =
  result = newList()
  for i in countdown(xs.high, 0):
    let el = xs[i]
    if el.isList and el.list.len > 1 and el.list[0] == newSymbol "splice-unquote":
      result = newList(newSymbol "concat", el.list[1], result)
    else:
      result = newList(newSymbol "unshift", result, quasiquote(el))

proc quasiquote(node: KelpNode): KelpNode =
  case node.kind
  of kpList:
    if node.list.len == 2 and node.list[0] == newSymbol "unquote":
      node.list[1]
    else:
      quasiloop(node.list)
  of kpVector:
    newList(newSymbol "concat", newVector(), quasiloop(node.list))
  of kpSymbol, kpTable:
    newList(newSymbol "quote", node)
  else:
    node

proc eval*(node: KelpNode, env: var KelpEnv, depth = 0): KelpNode

proc isMacroCall(node: KelpNode, env: KelpEnv): bool =
  if node.isList and node.list.len > 0 and node.list[0].isSymbol:
    let name = node.list[0].str
    let env = env.find(name)
    if env == nil: return false
    let sym = env.get(name)
    return sym.isFun and sym.isMacro
  # if node.isList and node.list.len > 0 and node.list[0].isSymbol and env.find(node.list[0].str) != nil:
  #   let sym = env.get(node.list[0].str)
  #   return sym.isFun and sym.isMacro

proc expand(node: KelpNode, env: KelpEnv, depth: int): KelpNode =
  result = node
  while result.isMacroCall(env):
    let fun = env.get(result.list[0].str)

    let args = result.list[1..^1]

    if args.len < fun.params.list.len: # i can't use util#execute here because of circular dependencies
      raise newException(ValueError, "insufficient amount of arguments, expected $1, got $2" % [$fun.params.list.len, $args.len])

    var scope = createScope(fun, args)

    result = fun.body.eval(scope, depth + 1).expand(env, depth + 1)

proc resolve(node: KelpNode, env: var KelpEnv, depth: int): KelpNode =
  case node.kind
  of kpSymbol:
    env.get(node.str)
  of kpList:
    newList node.list.mapIt(it.eval(env, depth + 1))
  of kpVector:
    newVector node.list.mapIt(it.eval(env, depth + 1))
  of kpTable:
    let res = KelpNode(kind: kpTable)
    for k, v in node.table.pairs:
      res.table[k] = v.eval(env, depth + 1)
    res
  else:
    node

proc eval*(node: KelpNode, env: var KelpEnv, depth = 0): KelpNode =
  if depth > 1500:
    raise newException(EvalError, "too much recursion, try optimizing your code for tco")

  var node = node
  var env = env

  template default = # i hate this
    let el = node.resolve(env, depth + 1)
    let fun = el.list[0]
    case fun.kind: # i can't use util#execute here because of circular dependencies
    of kpNative:
      return fun.fun(el.list[1 .. ^1])
    of kpFun:
      let xs = el.list[1..^1]
      if xs.len < fun.params.list.len:
        raise newException(EvalError, "insufficient amount of arguments, expected $1, got $2" % [$fun.params.list.len, $xs.len])

      var scope = createScope(fun, xs)

      node = fun.body
      env = scope
    else:
      raise newException(EvalError, "expected first list item to be a function")

  while true:
    node = node.expand(env, depth + 1)
    if not node.isList: return node.resolve(env, depth + 1)
    if node.list.len == 0: return node

    if node.list[0].isSymbol:
      # todo: make special forms not be hardcoded like this,
      # getting rid of hardcoded param checking with nim macros will be fun
      # todo: make special forms not be hardcoded like this,
      # not sure how i'd handle tco if i did that though
      # regarding the issue of modifying the env, it could just be a seperate param
      case node.list[0].str
      of "def!":
        if node.list.len < 3:
          raise newException(EvalError, "insufficient amount of arguments, expected 2, got " & $(node.list.len - 1))

        let
          key = node.list[1]
          val = node.list[2]

        if not key.isSymbol:
          raise newException(EvalError, "expected key to be a symbol")
        if key.str in SpecialForms:
          raise newException(EvalError, "cannot redefine special form")

        return env.set(key.str, val.eval(env, depth + 1))
      of "defmacro!":
        if node.list.len < 3:
          raise newException(EvalError, "insufficient amount of arguments, expected 2, got " & $(node.list.len - 1))

        let
          key = node.list[1]
          val = node.list[2].eval(env, depth + 1)

        if not key.isSymbol:
          raise newException(EvalError, "expected key to be a symbol")
        if not val.isFun:
          raise newException(EvalError, "expected value to be a function")
        if key.str in SpecialForms:
          raise newException(EvalError, "cannot redefine special form")

        val.isMacro = true

        return env.set(key.str, val)
      of "let*":
        if node.list.len < 3:
          raise newException(EvalError, "insufficient amount of arguments, expected 2, got " & $(node.list.len - 1))

        let
          binds = node.list[1]
          body = node.list[2]

        # if not binds.isTable:
        #   raise newException(EvalError, "expected binds to be a table")
        if not binds.isVector:
          raise newException(EvalError, "expected binds to be a vector")
        if binds.list.len mod 2 != 0:
          raise newException(EvalError, "expected even amount of bind items")

        var scope = newEnv(env)
        for i in countup(0, binds.list.high, 2):
          let k = binds.list[i]
          let v = binds.list[i + 1]

          if not k.isSymbol: raise newException(EvalError, "expected symbol as bind key")
          scope.set(k.str, v.eval(scope, depth + 1))
        # for k, v in binds.table: # is there a way to convert an OrderedTable into a Table?
        #   scope.set(k, v.eval(scope))

        node = body
        env = scope
      of "fn*":
        if node.list.len < 3:
          raise newException(EvalError, "insufficient amount of arguments, expected 2, got " & $(node.list.len - 1))

        let
          args = node.list[1]
          body = node.list[2]

        if not args.isVector:
          raise newException(EvalError, "expected args to be a vector")

        return newFun(args, body, env)
      of "defn!":
        if node.list.len < 4:
          raise newException(EvalError, "insufficient amount of arguments, expected 3, got " & $(node.list.len - 1))

        let
          key = node.list[1]
          args = node.list[2]
          body = node.list[3]

        node = newList(newSymbol("def!"), key, newList(newSymbol("fn*"), args, body))
      of "do":
        if node.list.len > 2:
          discard newList(node.list[1..^2]).resolve(env, depth + 1) # evaluate all except last
        node = node.list[^1] # eval and return last
      of "if":
        if node.list.len < 3:
          raise newException(EvalError, "insufficient amount of arguments, expected 2 or 3, got " & $(node.list.len - 1))

        let
          cond = node.list[1].eval(env, depth + 1)
          then = node.list[2]

        if cond.kind in {kpNil, kpFalse}: # only nil and false are falsey values
          if node.list.len > 3:
            node = node.list[3]
          else:
            node = nilObj
        else:
          node = then
      of "quote":
        if node.list.len < 2:
          raise newException(EvalError, "insufficient amount of arguments, expected 1, got " & $(node.list.len - 1))
        return node.list[1]
      of "quasiquote":
        if node.list.len < 2:
          raise newException(EvalError, "insufficient amount of arguments, expected 1, got " & $(node.list.len - 1))
        node = node.list[1].quasiquote()
      of "hashfn":
        if node.list.len < 2:
          raise newException(EvalError, "insufficient amount of arguments, expected 2, got " & $(node.list.len - 1))
        return newFun(newList(), node.list[1], env, false, true)
      else:
        default()
    else:
      default()

## notes for tomorrow
# native func will have "special" bool, don't resolve args if "special" bool is true
# ^ this is how special forms will be implemented, have a module that exports a proc that takes an env and returns
#   special funcs
# user funcs will have "macro" bool, do macro magic
