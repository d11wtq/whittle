require "spec_helper"

describe "a parser with a reduce-reduce conflict" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:wsp => /\s+/).skip!

      rule(:id => /[a-z]+/)

      rule(:list) do |r|
        r[:list, :id]
        r[:id]
      end

      rule(:prog) do |r|
        r[:list]
        r[:id]   # <- conflicts with :list := [:id]
      end

      start(:prog)
    end
  end

  it "raises a GrammarError" do
    expect { parser.new.parse("a b") }.to raise_error(Whittle::GrammarError)
  end

  it "specifies the rules that conflict" do
    begin
      parser.new.parse("a b")
    rescue Whittle::GrammarError => e
      e.message.should =~ /:prog := \[:id\]/
      e.message.should =~ /:list := \[:id\]/
    end
  end
end
