require "spec_helper"

describe "a parser with a nonterminal rule looking like a terminal" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule("+")

      rule(:prog) do |r|
        r["+"]
      end

      start(:prog)
    end
  end

  it "recognises the correct terminal" do
    parser.new.parse("+").should == "+"
  end
end
