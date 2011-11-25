require "spec_helper"

describe "a parser with a self-referential rule" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      start(:expr)

      rule(:expr) do |r|
        r[:expr, "+", :expr].as { |a, _, b| a + b }
        r[:int].as_value
      end

      rule(:int) do |r|
        r[/[0-9]+/].as { |int| Integer(int) }
      end

      rule(:plus) do |r|
        r["+"].as_value
      end

      rule(:paren) do |r|
        r[/[\(\)]/].as_value
      end
    end
  end

  it "handles the recursion gracefully" do
    parser.new.parse("2+3+1").should == 6
  end
end
