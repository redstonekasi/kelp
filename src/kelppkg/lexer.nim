# i know this doesn't seem ideal (defining all the types basically twice) but
# it's the nicest way to do this

# tokenize like before into special token enum types, have those be token objects
# similar to kelpnodes and store relevant data for strings, numbers etc inside them
# still store parens, brackets, curly raw and parse them later
# parser goes through tokens and constructs kelpnode

# hello kasi of tomorrow, i hope you understand this

# future kasi here, while i did understand it, after looking at other lisps i believe that this can definitively
# still be improved, so yeah i'll probably do that sometime

import std/[lexbase, streams, strutils, unicode]

type
  TokenKind* = enum tkEof, tkNil, tkTrue, tkFalse, tkNumber, tkSymbol,
    tkKeyword, tkString, tkSpecial, tkParenLe, tkParenRi, tkBracketLe, tkBracketRi,
    tkCurlyLe, tkCurlyRi

  Token* = object
    case kind*: TokenKind
    of tkNumber: num*: BiggestInt
    of tkSymbol, tkKeyword, tkString: str*: string
    of tkSpecial: lit*: char
    else: discard

  Lexer* = object of BaseLexer
    special: set[char]
    filename: string

  LexerError* = object of ValueError

const
  # i don't like that i have to specifiy all special chars manually but i don't have a better way of excluding those
  # i don't want if i don't
  NameChars = {'a'..'z', 'A'..'Z', '0'..'9', '!', '#', '$', '%', '&', '*', '+', '-', '/', ':'..'?', '\\'}

proc getLine*(l: Lexer): int {.inline.} = l.lineNumber
proc getColumn*(l: Lexer): int {.inline.} = l.getColNumber(l.bufpos)
proc getFilename*(l: Lexer): string {.inline.} = l.filename

proc newLexerError(l: Lexer, msg: string): ref LexerError =
  newException(LexerError, "$1($2:$3) $4" % [
    l.filename, $l.getLine(), $l.getColumn(), msg])

proc open*(l: var Lexer, stream: Stream, filename: string, special: set[char] = {})=
  lexbase.open(l, stream)
  l.special = special
  l.filename = filename

proc close*(l: var Lexer) =
  lexbase.close(l)

proc skip(l: var Lexer) =
  var pos = l.bufpos
  while true:
    case l.buf[pos]
    of ';':
      inc pos
      while true:
        case l.buf[pos]
        of '\0':
          break
        of '\c':
          pos = lexbase.handleCR(l, pos)
          break
        of '\l':
          pos = lexbase.handleLF(l, pos)
          break
        else:
          inc pos
    of ' ', '\t':
      inc pos
    of '\c':
      pos = lexbase.handleCR(l, pos)
    of '\l':
      pos = lexbase.handleLF(l, pos)
    else:
      break
  l.bufpos = pos

proc getToken*(l: var Lexer): Token

proc charToInt(c: char): int {.inline.} =
  ord(c) - ord('0')

proc parseNumber(l: var Lexer): Token =
  var
    pos = l.bufpos
    negative = false
  result = Token(kind: tkNumber)

  if l.buf[pos] == '-':
    negative = true
    inc pos

  while l.buf[pos] in Digits:
    result.num = result.num * 10 + charToInt(l.buf[pos])
    inc pos

  if negative: result.num = -result.num
  l.bufpos = pos

proc handleHexChar(c: char, x: var int): bool {.inline.} =
  result = true
  case c
  of '0'..'9': x = (x shl 4) or (ord(c) - ord('0'))
  of 'a'..'f': x = (x shl 4) or (ord(c) - ord('a') + 10)
  of 'A'..'F': x = (x shl 4) or (ord(c) - ord('A') + 10)
  else:
    result = false

proc parseUnicode(buf: string, pos: var int): int =
  for _ in 0..3:
    if handleHexChar(buf[pos], result):
      inc pos
    else:
      return -1

proc parseString(l: var Lexer): Token =
  result = Token(kind: tkString)
  var pos = l.bufpos + 1
  while true:
    case l.buf[pos]
    of '\0':
      raise l.newLexerError("'\"' expected")
    of '"':
      inc pos
      break
    of '\\':
      case l.buf[pos + 1]
      of '\\', '"', '\'', '/':
        result.str.add l.buf[pos + 1]
        inc(pos, 2)
      of 'n':
        result.str.add '\n'
        inc(pos, 2)
      of 'r':
        result.str.add '\r'
        inc(pos, 2)
      of 't':
        result.str.add '\t'
        inc(pos, 2)
      of 'u':
        inc(pos, 2)
        var r = parseUnicode(l.buf, pos)
        if r < 0:
          raise newException(LexerError, "invalid unicode codepoint")
        result.str.add toUTF8(Rune(r))
      else:
        result.str.add l.buf[pos]
    of '\c':
      pos = lexbase.handleCR(l, pos)
      result.str.add '\c'
    of '\l':
      pos = lexbase.handleLF(l, pos)
      result.str.add '\l'
    else:
      result.str.add l.buf[pos]
      inc pos
  l.bufpos = pos

proc parseName(l: var Lexer): Token =
  var
    pos = l.bufpos
    res = ""

  if l.buf[pos] == ':':
    res.add ':'
    inc pos

  if l.buf[pos] notin NameChars:
    raise newException(LexerError, "invalid char in name")

  while l.buf[pos] in NameChars:
    res.add l.buf[pos]
    inc pos

  if res.startsWith(':'):
    result = Token(kind: tkKeyword, str: res[1 .. res.len - 1])
  else:
    case res
    of "nil": result = Token(kind: tkNil)
    of "true": result = Token(kind: tkTrue)
    of "false": result = Token(kind: tkFalse)
    else: result = Token(kind: tkSymbol, str: res)

  l.bufpos = pos

proc getToken*(l: var Lexer): Token =
  l.skip()

  case l.buf[l.bufpos]
  of '0'..'9':
    l.parseNumber()
  of '"':
    l.parseString()
  of '(':
    inc l.bufpos
    Token(kind: tkParenLe)
  of '[':
    inc l.bufpos
    Token(kind: tkBracketLe)
  of '{':
    inc l.bufpos
    Token(kind: tkCurlyLe)
  of ')':
    inc l.bufpos
    Token(kind: tkParenRi)
  of ']':
    inc l.bufpos
    Token(kind: tkBracketRi)
  of '}':
    inc l.bufpos
    Token(kind: tkCurlyRi)
  of '\0':
    Token(kind: tkEof)
  else:
    if l.buf[l.bufpos] == '-' and l.buf[l.bufpos + 1] in Digits: # parse number
      l.parseNumber()
    elif l.buf[l.bufpos] in l.special: # parse parser macro
      inc l.bufpos
      Token(kind: tkSpecial, lit: l.buf[l.bufpos - 1])
    else: # parse symbol
      l.parseName()

# this is a utility function so i don't have to rewrite my parser too much
proc gatherTokens*(l: var Lexer): seq[Token] =
  while true:
    let tk = l.getToken()
    if tk.kind == tkEof: break
    result.add tk


proc eat*(l: var Lexer, token: TokenKind) =
  if l.getToken().kind != token:
    raise l.newLexerError($token & " expected")
    # TODO: make a mapping of token to name so the user doesn't get
    # tkEof expected instead of EOF
