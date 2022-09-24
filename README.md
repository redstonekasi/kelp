# kelp
Kasimir's Extraordinary List Processor

## Todo
- [ ] Rewrite the lexer and parser
- [ ] Write utility macro to avoid repitition in native definition
- [x] Fix string converting
- [ ] Documentation
- [ ] Library

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

### Lists / Vectors

### Tables
Tables in Kelp are what you might know as objects or hash maps in other programming languages.
```clojure
{:key "value" :abc 123}
```
| Signature | Description |
| --- | --- |
| `keys` | Returns a list of all keys in a table |
| `values` | Returns a list of all values in a table |
| `assoc <table1> <table2>` | Associate the key/value pairs of one table with another, merge them |
| `dissoc <table> <keywords...>` | Return a copy of the table with all specified keys removed, ignores keys that aren't present. |
