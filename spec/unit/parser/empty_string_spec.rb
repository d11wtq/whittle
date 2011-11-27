require "spec_helper"

describe "a parser matching the empty string" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:empty) do |r|
        r[].as   { "bob" }
      end

      start(:empty)
    end
  end

  it "always matches the empty string" do
    parser.new.parse("").should == "bob"
  end
end
