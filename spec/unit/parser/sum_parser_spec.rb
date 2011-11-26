require "spec_helper"

describe "a parser returning the sum of two integers" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule("+")

      rule(:int) do |r|
        r[/[0-9]+/].as { |int| Integer(int) }
      end

      rule(:sum) do |r|
        r[:int, "+", :int].as { |a, _, b| a + b }
      end

      start(:sum)
    end
  end

  it "returns the sum of the operands" do
    parser.new.parse("10+20").should == 30
  end
end
