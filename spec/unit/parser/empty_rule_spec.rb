require "spec_helper"

describe "a parser with an empty rule" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:expr) do |r|
        r[].as                { "test" }
        r["(", :expr, ")"].as { |_, expr, _| expr }
      end

      rule(:default) do |r|
        r[/./].as_value
      end

      start(:expr)
    end
  end

  it "injects the empty rule to allow matching the input" do
    parser.new.parse("((()))").should == "test"
  end
end
