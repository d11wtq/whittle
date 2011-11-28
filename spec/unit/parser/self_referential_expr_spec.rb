require "spec_helper"

describe "a parser with a self-referential rule" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule("(")
      rule(")")
      rule("+")

      rule(:int => /[0-9]+/).as { |int| Integer(int) }

      rule(:expr) do |r|
        r[:expr, "+", :expr].as { |a, _, b| a + b }
        r[:int].as(:value)
      end

      start(:expr)
    end
  end

  it "handles the recursion gracefully" do
    parser.new.parse("2+3+1").should == 6
  end
end
