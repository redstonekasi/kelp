import std/[tables, sequtils, oids]

type
  KelpKind* = enum kpNil, kpTrue, kpFalse, kpNumber, kpSymbol, kpKeyword,
    kpString, kpList, kpVector, kpTable, kpNative, kpFun, kpAtom

  FunType = proc(xs: varargs[KelpNode]): KelpNode

  KelpNode* = ref object
    case kind*: KelpKind
    of kpNil, kpTrue, kpFalse: nil
    of kpNumber: number*: BiggestInt
    of kpSymbol, kpKeyword, kpString: str*: string
    of kpList, kpVector: list*: seq[KelpNode]
    of kpTable: table*: OrderedTable[string, KelpNode]
    of kpNative: fun*: FunType
    of kpFun:
      params*: KelpNode
      body*: KelpNode
      env*: KelpEnv
      isMacro*: bool
      isHash*: bool
    of kpAtom:
      val*: KelpNode
      oid*: Oid # i hope you explode

  KelpEnv* = ref object
    data*: Table[string, KelpNode]
    parent*: KelpEnv

let nilObj* = KelpNode(kind: kpNil)
let trueObj* = KelpNode(kind: kpTrue)
let falseObj* = KelpNode(kind: kpFalse)

# init procedures
proc newNumber*(x: BiggestInt): KelpNode =
  KelpNode(kind: kpNumber, number: x)
proc newSymbol*(x: string): KelpNode =
  KelpNode(kind: kpSymbol, str: x)
proc newKeyword*(x: string): KelpNode =
  KelpNode(kind: kpKeyword, str: x)
proc newString*(x: string): KelpNode =
  KelpNode(kind: kpString, str: x)
proc newList*(xs: varargs[KelpNode]): KelpNode =
  KelpNode(kind: kpList, list: xs.toSeq)
proc newVector*(xs: varargs[KelpNode]): KelpNode =
  KelpNode(kind: kpVector, list: xs.toSeq)
proc newTable*(x: OrderedTable[string, KelpNode]): KelpNode =
  KelpNode(kind: kpTable, table: x)
proc newNative*(x: FunType): KelpNode =
  KelpNode(kind: kpNative, fun: x)
proc newFun*(params: KelpNode, body: KelpNode, env: KelpEnv, isMacro = false, isHash = false): KelpNode =
  KelpNode(kind: kpFun, params: params, body: body, env: env, isMacro: isMacro, isHash: isHash)
proc newAtom*(x: KelpNode): KelpNode =
  KelpNode(kind: kpAtom, val: x, oid: genOid())

proc boolObj*(b: bool): KelpNode =
  if b: trueObj else: falseObj

# type check procedures
proc isNil*(x: KelpNode): bool =
  x.kind == kpNil
proc isTrue*(x: KelpNode): bool =
  x.kind == kpTrue
proc isFalse*(x: KelpNode): bool =
  x.kind == kpFalse
proc isNumber*(x: KelpNode): bool =
  x.kind == kpNumber
proc isSymbol*(x: KelpNode): bool =
  x.kind == kpSymbol
proc isKeyword*(x: KelpNode): bool =
  x.kind == kpKeyword
proc isString*(x: KelpNode): bool =
  x.kind == kpString
proc isList*(x: KelpNode): bool =
  x.kind == kpList
proc isVector*(x: KelpNode): bool =
  x.kind == kpVector
proc isTable*(x: KelpNode): bool =
  x.kind == kpTable
proc isNative*(x: KelpNode): bool =
  x.kind == kpNative
proc isFun*(x: KelpNode): bool =
  x.kind == kpFun
proc isAtom*(x: KelpNode): bool =
  x.kind == kpAtom

# miscellaneous procedures
proc isSequential*(x: KelpNode): bool =
  x.kind in {kpList, kpVector}
proc isMacro*(x: KelpNode): bool =
  x.isFun and x.isMacro

proc `==`*(x, y: KelpNode): bool =
  if not (x.isSequential and y.isSequential):
    if x.kind != y.kind: return false
  case x.kind
  of kpNil, kpTrue, kpFalse: true
  of kpNumber: x.number == y.number
  of kpSymbol, kpKeyword, kpString: x.str == y.str
  of kpList, kpVector: x.list == y.list
  of kpTable: x.table == y.table
  of kpNative: x.fun == y.fun
  of kpFun: x.params == y.params and x.body == y.body and x.env == y.env
  of kpAtom: x.oid == y.oid
