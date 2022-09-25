import std/[strutils, sequtils, tables, oids], types

proc formatString*(x: string, repl: bool): string =
  if repl: '"' & x.multiReplace(("\"", "\\\""), ("\n", "\\n"), ("\\", "\\\\")) & '"'
  else: x

proc isRecursiveAtom(x: KelpNode, oid: Oid): bool =
  case x.kind
  of kpList, kpVector:
    for i in x.list:
      if isRecursiveAtom(i, oid): return true
  of kpTable:
    for i in x.table.values:
      if isRecursiveAtom(i, oid): return true
  of kpAtom:
    if x.oid == oid: return true
    elif x.val.isAtom: return isRecursiveAtom(x.val, oid)
  else:
    return false

proc `$`*(x: KelpNode, repl = true): string =
  case x.kind
  of kpNil: "nil"
  of kpTrue: "true"
  of kpFalse: "false"
  of kpNumber: $x.number
  of kpSymbol: x.str
  of kpKeyword: ':' & x.str
  of kpString: x.str.formatString(repl)
  of kpList: '(' & x.list.mapIt($it).join(" ") & ')'
  of kpVector: '[' & x.list.mapIt($it).join(" ") & ']'
  of kpTable:
    var res = "{"
    for key, val in x.table.pairs:
      if res.len > 1: res.add ' '
      res.add ':' & key & ' ' & $val
    res.add '}'
    res
  of kpNative: "<#native>"
  of kpFun:
    if x.isMacro: "<#macro>" else: "<#function>"
  of kpAtom:
    if isRecursiveAtom(x.val, x.oid):
      "<atom #" & $x.oid & ">"
    else:
      "<atom " & $x.val & '>'
