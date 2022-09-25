import std/tables, types

proc newEnv*(parent: KelpEnv = nil, data = initTable[string, KelpNode]()): KelpEnv =
  KelpEnv(data: data, parent: parent)

proc find*(e: KelpEnv, key: string): KelpEnv =
  if e.data.hasKey(key): return e
  if e.parent != nil: return e.parent.find(key)

proc set*(e: var KelpEnv, key: string, val: KelpNode): KelpNode {.discardable.} =
  e.data[key] = val
  val

proc get*(e: KelpEnv, key: string): KelpNode =
  let env = e.find(key)
  if env == nil: raise newException(ValueError, "'" & key & "' not found")
  env.data[key]
