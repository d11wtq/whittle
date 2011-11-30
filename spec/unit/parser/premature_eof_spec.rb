require "spec_helper"

describe "a parser receiving only partial input" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule("a")
      rule("b")
      rule("c")

      rule(";")

      rule(:abc) do |r|
        r["a", "b", "c"]
      end

      rule(:prog) do |r|
        r[:abc, ";"]
      end

      start(:prog)
    end
  end

  it "raises a parse error" do
    expect { parser.new.parse("abc") }.to raise_error(Whittle::ParseError)
  end

  it "reports the expected token" do
    begin
      parser.new.parse("abc")
    rescue Whittle::ParseError => e
      e.expected.should == [";"]
    end
  end

  it "indicates :$end as the received token" do
    begin
      parser.new.parse("abc")
    rescue Whittle::ParseError => e
      e.received.should == :$end
    end
  end
end
