# Kelp
Kasimir's Extraordinary List Processor

## Installation
```
nimble install https://github.com/redstonekasi/kelp
```

## Usage
### As a binary
Run `kelp` without any arguments to start the REPL.  
Use `kelp <filename>` loads the specified file and executes it's contents as Kelp code.

### As a library
TBA

## Todo
- [ ] Rewrite the lexer and parser
- [ ] Write utility macro to avoid repitition in native definition
- [x] Fix string converting
- [x] Documentation
- [ ] Explain all special forms and macros
- [ ] Make `defmacro!` used `defn!` syntax.
- [ ] Library documentation
- [ ] Analyse hash functions for proper argument checking
- [ ] Bignums

## Documentation
### Math functions
All math functions take an infinite amount of parameters and applies the specified function on them.
```clojure
(+ 7 (* 3 4) 2) ; 21
```
| Symbol | Function |
| --- | --- |
| `+` | addition |
| `-` | subtraction |
| `*` | multiplication |
| `%` | modulo |
| `/` | division |

### Comparison functions
All comparison functions take exactly two parameters and compare them.
```clojure
(> 10 12) ; true
(< 16 21) ; false
```
| Symbol | Function |
| --- | --- |
| `<` | less than |
| `>` | greater than |
| `<=` | less than or equal to |
| `>=` | greater than or equal to |
| `=` | equals |

### Boolean functions
| Signature | Description |
| --- | --- |
| `and <bools...>` | Returns true if all parameters are true. |
| `or <bools...>` | Returns true if at least one parameters is true. |
| `not <bool>` | Returns true if passed false, false if passed true. |

### Lists / Vectors
Lists and vectors represent lists of values.
```clojure
(+ 2 4) ; 6
(list "hello" "world" 123) ; list: ("hello" "world" 123)
["hello" 123 :test] ; vector: ["hello" 123 :test]
```
| Signature | Description |
| --- | --- |
| `len <list/vector>` | Returns amount of items in list or vector. |
| `empty? <list/vector>` | Returns whether or not a list/vector is empty. |
| `nth <list/vector> <index>` | Returns the *n*th item in a list or vector. |
| `slice <list/vector> <start> <end>` | Returns a slice of *list/vector* from *start* to *end*, inclusive. |
| `unshift <list/vector> <value>` | Returns a list/vector that has the specified value prepended to it. |
| `concat <lists/vectors...>` | Returns a list/vector that is the concatenation of all list/vector parameters, return type is specified by the type of the first list. |
| `map <list/vector> <function>` | Returns the a list/vector of the results of calling the specified function on each of the elements of the specified list/vector. |
| `string <values...>` | Returns a stringified reprensentation of all the passed arguments joined together.

### Tables
Tables in Kelp are what you might know as objects or hash maps in other programming languages.
```clojure
{:key "value" :abc 123}
```
| Signature | Description |
| --- | --- |
| `keys` | Returns a list of all keys in a table |
| `values` | Returns a list of all values in a table |
| `assoc <table> (<keyword> <value>)...` | Takes a number of key value pairs and returns the result of associating them with the given table. |
| `dissoc <table> <keywords...>` | Returns a copy of the table with all specified keys removed, ignores keys that aren't present. |

### Miscellaneous functions
I'm not sure where to put these functions so here they go.
| Signature | Description |
| --- | --- |
| `has? <list/vector/table> <value/keyword>` | If a list or vector is passed, returns whether or not they contain the specified value. If a table is passed, checks whether or not the specified keyword is set. |
| `call <function> <params...> <list/vector>` | Takes a function and calls it with a concatenation of all parameters and the last parameter. This allows you to call a function with arguments that are in a list. For example: `(call + 1 2 3 [4 5 6])` is equal to `(+ 1 2 3 4 5 6)`. |

### Instantiation functions
| Signature | Description |
| --- | --- |
| `symbol <string>` | Returns a symbol with the name of the specified string |
| `keyword <string>` | Returns a keyword with the name of the specified string |
| `list <values...>` | Returns a list of the passed parameters |
| `vector <values...>` | Returns a vector of the passed parameters |
| `atom <value>` | Returns an atom that references the specified value |

### Atoms
An atom holds a reference to a single kelp value of any type, it's how you represent state.
```clojure
(def! test (atom 123))
(deref test) ; 123
(assign! test 456) ; 456
(apply! test (fn* [x] (+ x 1))) ; 457
```
| Signature | Description |
| --- | --- |
| `deref <atom>` | Returns the value referenced by the specified atom |
| `assign! <atom> <value>` | Modifies an atom to refer to the given value, returns that value. |
| `apply! <atom> <function>` | Modifies an atom's value to the result of calling the specified function with the atom's value, returns the new value. |

### Type checking
These functions all take a value and return whether or not that value is of the specified type.
| Function | Checks for |
| --- | --- |
| `nil?` | nil |
| `true?` | true |
| `false?` | false |
| `number?` | number |
| `symbol?` | symbol |
| `keyword?` | keyword |
| `string?` | string |
| `list?` | list |
| `vector?` | vector |
| `table?` | table |
| `native?` | native function |
| `fun?` | function |
| `atom?` | atom |
| `sequential?` | list or vector |
| `macro?` | macro |

### Executeable environment
These functions will only be available in the REPL and when executing a file. This will only matter once Kelp is functional as a library.
| Signature | Description |
| --- | --- |
| `echo <values...>` | Prints a stringified representation of all passed arguments joined together with a space and returns nil.
| `debug <values...>` | Same as `echo` but stringifies the values with REPL formatting. |
| `parse <string>` | Parses the specified string into a Kelp type. |
| `file <string>` | Reads the contents of a file at the specified path. |
| `eval <value>` | Evaluates the paseed value. |
| `load <string>` | Reads the contents of a file, parses them and evaluates them |

#### Only available in files
| Signature | Description |
| --- | --- |
| `ARGV` | This is not a function but  a list of arguments passed to kelp. |

## Metaprogramming
### Quotes
#### `quote`
The `quote` special form indicates to Kelp that the given value should not be evaluated.
```clojure
abc ; results in an error: 'abc' not found
(quote abc) ; returns abc
(1 2 3) ; results in an error: '1' is not a function
(quote (1 2 3)) ; returns (1 2 3)
```

#### `quasiquote`
The `quasiquote` special form works the same way as `quote`, except that it also allows you to have unquoted (evaluated) items in a quoted list. For this purpose two special forms are available within `quasiquote`: `unquote` and `splice-unquote`.  
`unquote` evaluates its argument and puts it in its place in the quasiquoted list. `splice-unquote` also evaluates its argument, but the result is then spliced into the quasiquoted list.
```clojure
(def! test (quote (b c))) ; (b c)
(quasiquote (a test d)) ; (a test d)
(quasiquote (a (unquote test) d)) ; (a (b c) d)
(quasiquote (a (splice-unquote test) d)) ; (a b c d)
```

#### Short forms
```clojure
'(123) -> (quote (1 2 3))
`(a test d) -> (quasiquote (a test d))
`(a ~test d) -> (quasiquote (a (unquote test) d))
`(a ^test d) -> (quasiquote (a (splice-unquote test) d))
```

### Macros
Macros are special functions defined using the `defmacro!` special form, which takes a symbol and a function.  
Macros work exactly likes functions, except that the arguments passed to your macro aren't evaluated by Kelp.
```clojure
(defmacro! unless (fn* [p a b] `(if ~p ~b ~a)))
```
