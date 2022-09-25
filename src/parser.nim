import std/[streams, tables, setutils], lexer, types

type
  Parser = object
    tokens: seq[Token]
    pos: int

  ParserError = object of ValueError

proc parse(p: var Parser): KelpNode

const macros = {
  '\'': proc(p: var Parser): KelpNode = newList(newSymbol "quote", p.parse()),
  '`': proc(p: var Parser): KelpNode = newList(newSymbol "quasiquote", p.parse()),
  '~': proc(p: var Parser): KelpNode = newList(newSymbol "unquote", p.parse()),
  '^': proc(p: var Parser): KelpNode = newList(newSymbol "splice-unquote", p.parse()),
  '@': proc(p: var Parser): KelpNode = newList(newSymbol "deref", p.parse())
}.toTable

# some helper functions to make transitioning from the old parser easier
proc next(p: var Parser): Token =
  if p.pos < p.tokens.len:
    result = p.tokens[p.pos]
    inc p.pos

proc peek(p: Parser): Token =
  if p.pos < p.tokens.len:
    return p.tokens[p.pos]

proc parseSequence(p: var Parser, to: TokenKind): seq[KelpNode] =
  discard p.next()
  while p.peek().kind != to:
    result.add p.parse()
  discard p.next()

proc parseTable(p: var Parser): OrderedTable[string, KelpNode] =
  discard p.next()
  while p.peek().kind != tkCurlyRi:
    let key = p.next()
    if key.kind != tkKeyword:
      # TODO: Store line and column in Token for better errors
      raise newException(ParserError, "expected keyword as key")
    let val = p.parse()
    result[key.str] = val
  discard p.next()

proc parse(p: var Parser): KelpNode =
  case p.peek().kind
  of tkNil:
    discard p.next()
    nilObj
  of tkTrue:
    discard p.next()
    trueObj
  of tkFalse:
    discard p.next()
    falseObj
  of tkNumber: newNumber p.next().num
  of tkSymbol: newSymbol p.next().str
  of tkKeyword: newKeyword p.next().str
  of tkString: newString p.next().str
  of tkParenLe: newList p.parseSequence(tkParenRi)
  of tkParenRi: raise newException(ParserError, "unexpected ')'")
  of tkBracketLe: newVector p.parseSequence(tkBracketRi)
  of tkBracketRi: raise newException(ParserError, "unexpected ']'")
  of tkCurlyLe: newTable p.parseTable()
  of tkCurlyRi: raise newException(ParserError, "unexpected '}'")
  of tkSpecial:
    let special = p.next().lit
    if special in macros:
      macros[special](p)
    else: raise newException(ParserError, "invalid special parser macro")
  of tkEof: raise newException(ParserError, "unexpected EOF")

proc parse*(s: Stream, filename = ""): KelpNode =
  var l: Lexer
  l.open(s, filename, macros.keys.toSet)

  try:
    var p = Parser(tokens: l.gatherTokens())
    if p.tokens.len == 0: return nilObj
    result = p.parse()
  finally:
    l.close()

proc parse*(buffer: string, filename = "input"): KelpNode =
  parse(newStringStream(buffer), "input")
