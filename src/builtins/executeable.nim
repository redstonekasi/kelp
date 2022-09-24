import std/[tables, sequtils, strutils], ../types, ../printer, ../parser

proc echoString(xs: varargs[KelpNode]): KelpNode =
  echo xs.mapIt(`$`(it, false)).join(" ")
  nilObj

proc debugString(xs: varargs[KelpNode]): KelpNode =
  echo xs.mapIt($it).join(" ")
  nilObj

proc parse(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  if not xs[0].isString:
    raise newException(ValueError, "expected string as first argument")
  xs[0].str.parse

proc file(xs: varargs[KelpNode]): KelpNode =
  if xs.len < 1:
    raise newException(ValueError, "unexpected number of arguments, expected 1, got " & $xs.len)
  if not xs[0].isString:
    raise newException(ValueError, "expected string as first argument")
  newString readFile(xs[0].str)

let exeNamespace* = {
  "echo": newNative echoString,
  "debug": newNative debugString,

  "parse": newNative parse,
  "file": newNative file,
}.toTable
