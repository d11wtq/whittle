require "spec_helper"

describe "a parser with logical grouping" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:expr) do |r|
        r["(", :expr, ")"].as   { |_, expr, _| expr }
        r[:expr, "-", :expr].as { |a, _, b| a - b }
        r[:int].as_value
      end

      rule(:int) do |r|
        r[/[0-9]+/].as { |int| Integer(int) }
      end

      rule("(")
      rule(")")
      rule("-") % :left

      start(:expr)
    end
  end

  it "parses the grouping first" do
    parser.new.parse("2-(3-1)-1").should == -1
  end
end
