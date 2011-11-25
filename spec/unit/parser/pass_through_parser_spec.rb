require "spec_helper"

describe "a pass-through parser" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:foo) do |r|
        r["FOO"].as_value
      end

      start(:foo)
    end
  end

  it "returns the input" do
    parser.new.parse("FOO").should == "FOO"
  end
end
