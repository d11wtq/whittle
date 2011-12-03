require "spec_helper"

describe "parsing according to a different start rule" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule("+")
      rule("-")

      rule(:int => /[0-9]+/).as { |i| Integer(i) }

      rule(:sum) do |r|
        r[:int, "+", :int].as { |a, _, b| a + b }
      end

      rule(:sub) do |r|
        r[:sum, "-", :sum].as { |a, _, b| a - b }
      end

      start(:sub)
    end
  end

  it "ignores the defined start rule and uses the specified one" do
    parser.new.parse("1+2", :rule => :sum).should == 3
  end
end
