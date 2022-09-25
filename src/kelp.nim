import std/[rdstdin, os, sequtils], builtins/[core, executeable], environment, eval, parser, printer, types

when isMainModule:
  var exeEnv = newEnv(nil, exeNamespace) # is there no way to merge normal tables in nim?
  var env = newEnv(exeEnv, coreNamespace)

  proc rep(str: string): string {.discardable.} =
    $str.parse.eval(env)

  proc evil(xs: varargs[KelpNode]): KelpNode =
    if xs.len < 1:
      raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
    xs[0].eval(env)

  env.set("eval", newNative evil)
  rep "(def! load (fn* [f] (eval (parse (string \"(do \" (file f) \"\nnil)\")))))"

  if paramCount() >= 1:
    env.set("ARGV", newList((if paramCount() > 1: commandLineParams()[1..^1] else: @[]).map(newString)))
    try:
      rep readFile(paramStr(1))
    except:
      echo "Error: " & getCurrentExceptionMsg()
    quit()

  while true:
    try:
      let input = readLineFromStdin("kelp> ")
      let res = input.parse
      if not res.isNil:
        echo res.eval(env)
    except IOError: quit()
    except:
      echo "Error: " & getCurrentExceptionMsg()
