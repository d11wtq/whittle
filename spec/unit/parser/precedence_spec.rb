require "spec_helper"

describe "a parser depending on operator precedences" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule("+") % :left ^ 1
      rule("*") % :left ^ 2

      rule(:int) do |r|
        r[/[0-9]+/].as { |i| Integer(i) }
      end

      rule(:expr) do |r|
        r[:expr, "+", :expr].as { |a, _, b| a + b }
        r[:expr, "*", :expr].as { |a, _, b| a * b }
        r[:int].as(:value)
      end

      start(:expr)
    end
  end

  it "resolves shift-reduce conflicts by precedence" do
    parser.new.parse("1+2*3").should == 7
  end
end
