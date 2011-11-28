# Whittle: A little LALR(1) Parser in Pure Ruby — Not a Generator

Whittle is a LALR(1) parser.  It's very small, easy to understand, and what's most important,
it's 100% ruby.  You write parsers by specifying sequences of allowable rules (which refer to
other rules, or even to themselves).  For each rule in your grammar, you provide a block that
is invoked when the grammar is recognized.

If you're *not* familiar with parsing, you should find Whittle to be a very friendly little
parser.

It is related, somewhat, to yacc and bison, which belong to the class of parsers known as
LALR(1): Left-Right, using 1 Lookahead token.  This class of parsers is both easy to work with
and particularly powerful (ruby itself is parsed using a LALR(1) parser).  Since the algorithm
is based around a theory that *never* has to backtrack (that is, each token read takes the
parse forward, with just a single lookup in a parse table), parse time is also fast.  Parse
time is governed by the size of the input, not by the size of the grammar.

Whittle provides meaningful error reporting (line number, expected tokens, received token) and
even lets you hook into the error handling logic if you need to write some sort of crazy
madman-forgiving parser.

If you've had issues with other parsers hitting "stack level too deep" errors, you should find
that Whittle does not suffer from the same issues, since it uses a state-switching algorithm
(a pushdown automaton to be precise), rather than simply having one parse function call another
and so on.  Whittle also supports the following concepts:

  - Left/right recursion
  - Left/right associativity
  - Operator precedences
  - Skipping of silent tokens in the input (e.g. whitespace/comments)

## Installation

Via rubygems:

    gem install whittle

Or in your Gemfile, if you're using bundler:

    gem 'whittle'

## The Basics

Parsers using Whittle do not generate ruby code from a grammar file.  This may strike users of
other LALR(1) parsers as odd, but c'mon, we're using Ruby, right?

I'll avoid discussing the algorithm until we get into the really advanced stuff, but you will
need to understand a few fundamental ideas before we begin.

  1. There are two types of rule that make up a complete parser: *terminal*, and *nonterminal*
    - A terminal rule is quite simply a chunk of the input string, like '42', or 'function'
    - A nonterminal rule is a rule that makes reference to other rules (both terminal and
      nonterminal)
  2. The input to be parsed *always* conforms to just one rule at the topmost level.  This is
     known as the "start rule" and describes the structure of the program as a whole.

The easiest way to understand how the parser works is just to learn by example, so let's see an
example.

``` ruby
require 'whittle'

class Mathematician < Whittle::Parser
  rule("+")

  rule(:int) do |r|
    r[/[0-9]+/].as { |num| Integer(num) }
  end

  rule(:expr) do |r|
    r[:int, "+", :int].as { |a, _, b| a + b }
  end

  start(:expr)
end

mathematician = Mathematician.new
mathematician.parse("1+2")
# => 3
```

Let's break this down a bit.  As you can see, the whole thing is really just `rule` used in
different ways.  We also have to set the start rule that we can use to describe an entire
program, which in this case is the `:expr` rule that can add two numbers together.

There are two terminal rules (`"+"` and `:int`) and one nonterminal (`:expr`) in the above
grammar.  Each rule can have a block attached to it.  The block is invoked with the result
evaluating the blocks attached to each of its inputs (in a depth-first manner).  Calling `rule`
with no block is just a shorthand for saying "return the matched input verbatim", so our "+"
above will receive the string "+" and return the string "+".  Since this is such a common
use-case, Whittle offers the shorthand.

As the input string is parsed, it *must* match the start rule `:expr`.

Let's step through the parse for the above input "1+2".  When the parser starts, it looks at
the start rule `:expr` and decides what tokens would be valid if they were encountered. Since
`:expr` starts with `:int`, the only thing that would be valid is anything matching
`/[0-9]+/`. When the parser reads the "1", it recognizes it as an `:int`, puts at aside (puts
it on the stack, in technical terms).  Now it advances through the rule for `:expr` and
decides the only possible valid input would be a "+", and finally the last `:int`.  Upon
having read the sequence `:int`, "+", `:int`, our block attached to that rule is invoked to
return a result.  First the three inputs are passed through their respective blocks (so the
"1" and the "2" are cast to integers, according to the rule for `:int`), then they are passed
to the `:expr`, which adds the 1 and the 2 to make 3.  Magic!

## Nonterminal rules can have more than one valid sequence

Our mathematician class above is not much of a mathematician.  It can only add numbers together.
Surely subtraction, division and multiplication should be possible too?

It turns out that this is really simple to do.  Just add multiple possibilities to the same
rule.

``` ruby
require 'whittle'

class Mathematician < Whittle::Parser
  rule("+")
  rule("-")
  rule("*")
  rule("/")

  rule(:int) do |r|
    r[/[0-9]+/].as { |num| Integer(num) }
  end

  rule(:expr) do |r|
    r[:int, "+", :int].as { |a, _, b| a + b }
    r[:int, "-", :int].as { |a, _, b| a - b }
    r[:int, "*", :int].as { |a, _, b| a * b }
    r[:int, "/", :int].as { |a, _, b| a / b }
  end

  start(:expr)
end

mathematician = Mathematician.new

mathematician.parse("1+2")
# => 3

mathematician.parse("1-2")
# => -1

mathematician.parse("2*3")
# => 6

mathematician.parse("4/2")
# => 2
```

Now you're probably beginning to see how matching just one rule for the entire input is not a
problem.  To think about a more real world example, you can describe most programming
languages as a series of statements and constructs.

## Rules can refer to themselves

But our mathematician is still not very bright.  It can only work with two operands.  What about
more complex expressions?

``` ruby
require 'whittle'

class Mathematician < Whittle::Parser
  rule("+")
  rule("-")
  rule("*")
  rule("/")

  rule(:int) do |r|
    r[/[0-9]+/].as { |num| Integer(num) }
  end

  rule(:expr) do |r|
    r[:expr, "+", :expr].as { |a, _, b| a + b }
    r[:expr, "-", :expr].as { |a, _, b| a - b }
    r[:expr, "*", :expr].as { |a, _, b| a * b }
    r[:expr, "/", :expr].as { |a, _, b| a / b }
    r[:int].as(:value)
  end

  start(:expr)
end

mathematician = Mathematician.new
mathematician.parse("1+5-2")
# => 4
```

Adding a rule of just `:int` to the `:expr` rule means that any integer is also a valid `:expr`.
It is now possible to say that any `:expr` can be added to, multiplied by, divided by or
subtracted from another `:expr`.  It is this ability to self-reference that makes LALR(1)
parsers so powerful and easy to use.  Note that because the result each input to any given rule
is computed *before* being passed as arguments to the block, each `:expr` in the calculations
above will always be a number, since each `:expr` returns a number.  The recursion in these rules
is practically limitless.  You can write "1+2-3*4+775/3" and it's still an `:expr`.

## Specifying the associativity

If we poke around for more than a few seconds, we'll soon realize that our mathematician  makes
some silly mistakes.  Let's see what happens when we do the following:

``` ruby
mathematician.parse("6-3-1")
# => 4
```

Oops.  That's not correct.  Shouldn't the answer be 2?

Our grammar is ambiguous.  The input string could be interpreted as either:

    6-(3-1)

Or as:

    (6-3)-1

Basic arithmetic takes the latter approach, but the parser's default approach is to go the other
way.  We refer to these two alternatives as being left associative (the second example) and
right associative (the first example).  By default, operators are right associative, which means
as much input will be read as possible before beginning to compute a result.

We can correct this by tagging our operators as left associative.

``` ruby
require 'whittle'

class Mathematician < Whittle::Parser
  rule("+") % :left
  rule("-") % :left
  rule("*") % :left
  rule("/") % :left

  rule(:int) do |r|
    r[/[0-9]+/].as { |num| Integer(num) }
  end

  rule(:expr) do |r|
    r[:expr, "+", :expr].as { |a, _, b| a + b }
    r[:expr, "-", :expr].as { |a, _, b| a - b }
    r[:expr, "*", :expr].as { |a, _, b| a * b }
    r[:expr, "/", :expr].as { |a, _, b| a / b }
    r[:int].as(:value)
  end

  start(:expr)
end

mathematician = Mathematician.new
mathematician.parse("6-3-1")
# => 2
```

Attaching a percent sign followed by either `:left` or `:right` changes the associativity of a
terminal rule.  We now get the correct result.

## Specifying the operator precedence

Basic arithmetic is easy peasy, right?  Well, despite fixing the associativity, we find we still
have a problem:

``` ruby
mathematician.parse("1+2*3")
# => 9
```

Hmm.  The expression has been interpreted as (1+2)*3.  It turns out arithmetic is not as simple
as one might think ;)  The parser does not (yet) know that the multiplication operator has a
higher precedence than the addition operator.  We need to indicate this in the grammar.

``` ruby
require 'whittle'

class Mathematician < Whittle::Parser
  rule("+") % :left ^ 1
  rule("-") % :left ^ 1
  rule("*") % :left ^ 2
  rule("/") % :left ^ 2

  rule(:int) do |r|
    r[/[0-9]+/].as { |num| Integer(num) }
  end

  rule(:expr) do |r|
    r[:expr, "+", :expr].as { |a, _, b| a + b }
    r[:expr, "-", :expr].as { |a, _, b| a - b }
    r[:expr, "*", :expr].as { |a, _, b| a * b }
    r[:expr, "/", :expr].as { |a, _, b| a / b }
    r[:int].as(:value)
  end

  start(:expr)
end

mathematician = Mathematician.new
mathematician.parse("1+2*3")
# => 7
```

That's better.  We can attach a precedence level to a rule by following it with the caret `^`,
followed by an integer value.  The higher the value, the higher the precedence.  Note that "+"
and "-" both have the same precedence, since "1+(2-3)" and "(1+2)-3" are logically equivalent.
The same applies to "*" and "/", but these both usually have a higher precedence than "+" and
"-".

## Disambiguating expressions with the use of parentheses

Sometimes we really do want "1+2*3" to mean "(1+2)*3", so we should really support this in our
mathematician class.  Fortunately adjusting the syntax rules in Whittle is a painless exercise.

``` ruby
require 'whittle'

class Mathematician < Whittle::Parser
  rule("+") % :left ^ 1
  rule("-") % :left ^ 1
  rule("*") % :left ^ 2
  rule("/") % :left ^ 2

  rule("(")
  rule(")")

  rule(:int) do |r|
    r[/[0-9]+/].as { |num| Integer(num) }
  end

  rule(:expr) do |r|
    r["(", :expr, ")"].as   { |_, exp, _| exp }
    r[:expr, "+", :expr].as { |a, _, b| a + b }
    r[:expr, "-", :expr].as { |a, _, b| a - b }
    r[:expr, "*", :expr].as { |a, _, b| a * b }
    r[:expr, "/", :expr].as { |a, _, b| a / b }
    r[:int].as(:value)
  end

  start(:expr)
end

mathematician = Mathematician.new
mathematician.parse("(1+2)*3")
# => 9
```

All we had to do was add the new terminal rules for "(" and ")" then specify that the value of
an expression enclosed in parentheses is simply the value of the expression itself.  We could
just as easily pick some other characters to surround the grouping (maybe "~1+2~*3"), but then
people would think we were silly (arguably, we would be a bit silly).

## Skipping whitespace

Most languages contain tokens that are ignored when interpreting the input, such as whitespace
and comments.  Accounting for the possibility of these in all rules would be both wasteful and
tiresome.  Instead, we skip them entirely, by declaring a terminal rule without any associated
action, or if you want to be explicit, with `as(:nothing)`.

``` ruby
require 'whittle'

class Mathematician < Whittle::Parser
  rule(:wsp) do |r|
    r[/\s+/]
  end

  rule("+") % :left ^ 1
  rule("-") % :left ^ 1
  rule("*") % :left ^ 2
  rule("/") % :left ^ 2

  rule("(")
  rule(")")

  rule(:int) do |r|
    r[/[0-9]+/].as { |num| Integer(num) }
  end

  rule(:expr) do |r|
    r["(", :expr, ")"].as   { |_, exp, _| exp }
    r[:expr, "+", :expr].as { |a, _, b| a + b }
    r[:expr, "-", :expr].as { |a, _, b| a - b }
    r[:expr, "*", :expr].as { |a, _, b| a * b }
    r[:expr, "/", :expr].as { |a, _, b| a / b }
    r[:int].as(:value)
  end

  start(:expr)
end

mathematician = Mathematician.new
mathematician.parse("( 1 + 2)*3 - 4")
# => 5
```

Now the whitespace can either exist between the tokens in the input or not.  The parser doesn't
pay attention to it, it simply discards it as the input string is read.

## Rules can be empty

Sometimes you want to describe a structure, such as a list, that may have zero or more items in
it. In order to do this, the empty rule comes in extremely useful.  Imagine the input string:

    (((())))

We can say that this is matched by any pair of parentheses inside any pair of parentheses, any
number of times. But what's in the middle?

``` ruby
require 'whittle'

class Parser < Whittle::Parser
  rule("(")
  rule(")")

  rule(:parens) do |r|
    r[]
    r["(", :parens, ")"]
  end

  start(:parens)
end
```

The above parser will happily match our input, because it is possible for the `:parens` rule to
match nothing at all, which is what we hit in the middle of our nested parentheses.

This is most useful in constructs like the following:

``` ruby
rule(:id) do |r|
  r[/[a-z]+/].as(:value)
end

rule(:list) do |r|
  r[].as                { [] }
  r[:list, ",", :id].as { |list, _, id| list << id }
  r[:id].as             { |id| [id] }
end
```

The following would return the array `["a", "b", "c"]` given the input string "a, b, c", or
given the input string "" (nothing) it would return the empty array.

## Parse errors

### The default error reporting

When the parser encounters an unexpected token in the input, an exception of type
`Whittle::ParseError` is raised.  The exception has a very clear message, indicates the line on
which the error was encountered, and additionally gives you programmatic access to the same
information.

``` ruby
class ListParser < Whittle::Parser
  rule(:wsp) do |r|
    r[/\s+/]
  end

  rule(:id) do |r|
    r[/[a-z]+/].as(:value)
  end

  rule(",")
  rule("-")

  rule(:list) do |r|
    r[:list, ",", :id].as { |list, _, id| list << id }
    r[:id].as             { |id| Array(id) }
  end

  start(:list)
end

ListParser.new.parse("a, \nb, \nc- \nd")

# =>
# Parse error: expected "," but got "-" on line 3
```

You can also access `#line`, `#expected` and `#received` if you catch the exception.

### Recovering from a parse error

It is possible to override the `#error` method in the parser to do something smart if you
believe there to be easily resolved parse errors (such as switching the input token to
something else, or rewinding the parse stack to a point where the error would not manifest.  I
need to write some specs on this and explore it fully myself before I document it.  99% of users
would never need to do such a thing.

## More examples

There are some runnable examples included in the examples/ directory.  Playing around with these
would probably be a useful exercise.

If you have any examples you'd like to contribute, I will gladly add them to the repository.

## TODO

  - Improve the DSL for declaring basic terminal rules.
  - Provide a more powerful (state based) lexer algorithm, or at least document how users can
    override `#lex`.
  - Allow inspection of the parse table (it is not very human friendly right now).
  - Allow inspection of the AST (maybe).
  - Given in an input String, provide a human readble explanation of the parse.

## License & Copyright

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Copright (c) Chris Corbyn, 2011
