require "spec_helper"

describe "a parser with multiple precedence levels" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:expr) do |r|
        r["(", :expr, ")"].as   { |_, expr, _| expr }
        r[:expr, "+", :expr].as { |a, _, b| a + b }
        r[:expr, "-", :expr].as { |a, _, b| a - b }
        r[:expr, "*", :expr].as { |a, _, b| a * b }
        r[:expr, "/", :expr].as { |a, _, b| a / b }
        r[:int].as(:value)
      end

      rule(:int) do |r|
        r[/[0-9]+/].as { |int| Integer(int) }
      end

      rule("(")
      rule(")")
      rule("+") % :left ^ 1
      rule("-") % :left ^ 1
      rule("*") % :left ^ 2
      rule("/") % :left ^ 2

      start(:expr)
    end
  end

  it "evaluates each precedence as it is encountered" do
    parser.new.parse("4-2*3-(6/3)/2+1").should == -2
  end
end
