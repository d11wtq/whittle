# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

# This example creates a simple infix calculator, supporting the four basic arithmetic
# functions, add, subtract, multiply and divide, along with logic grouping and operator
# precedence

require "whittle"
require "bigdecimal"

class Calculator < Whittle::Parser
  rule(:wsp) { |r| r[/\s+/] } # skip whitespace

  rule("+") % :left ^ 1
  rule("-") % :left ^ 1
  rule("*") % :left ^ 2
  rule("/") % :left ^ 2

  rule("(")
  rule(")")

  rule(:decimal) do |r|
    r[/([0-9]*\.)?[0-9]+/].as { |num| BigDecimal(num) }
  end

  rule(:expr) do |r|
    r["(", :expr, ")"].as   { |_, e, _| e }
    r[:expr, "+", :expr].as { |a, _, b| a + b }
    r[:expr, "-", :expr].as { |a, _, b| a - b }
    r[:expr, "*", :expr].as { |a, _, b| a * b }
    r[:expr, "/", :expr].as { |a, _, b| a / b }
    r["-", :expr].as        { |_, e| -e }
    r[:decimal].as(:value)
  end

  start(:expr)
end

calculator = Calculator.new

p calculator.parse("5-2-1").to_f
# => 2

p calculator.parse("5-2*3").to_f
# => -1

p calculator.parse(".7").to_f
# => 0.7

p calculator.parse("3.3 - .7").to_f
# => 2.6

p calculator.parse("5-(2-1)").to_f
# => 4

p calculator.parse("5 - -2").to_f
# => 7

p calculator.parse("5 * 2 - -2").to_f
# => 12
