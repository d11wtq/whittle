require "spec_helper"

describe "a parser expecting a fixed amount of input" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule("a")
      rule("b")
      rule("c")

      rule(:prog) do |r|
        r["a", "b", "c"]
      end

      start(:prog)
    end
  end

  it "raises a parse error if additional input is encountered" do
    expect { parser.new.parse("abcabc") }.to raise_error(Whittle::ParseError)
  end

  it "indicates that :$end is the expected token" do
    begin
      parser.new.parse("abcabc")
    rescue Whittle::ParseError => e
      e.expected.should == [:$end]
    end
  end

  it "indicates that the first surplus token is the received input" do
    begin
      parser.new.parse("abcabc")
    rescue Whittle::ParseError => e
      e.received.should == "a"
    end
  end
end
