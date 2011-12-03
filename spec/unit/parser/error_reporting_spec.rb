require "spec_helper"

describe "a parser encountering unexpected input" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:wsp => /\s+/).skip!

      rule(:id => /[a-z]+/)

      rule(",")
      rule("-")

      rule(:list) do |r|
        r[:list, ",", :id].as { |list, _, id| list << id }
        r[:id].as             { |id| Array(id) }
      end

      start(:list)
    end
  end

  it "raises an exception of type ParseError" do
    expect {
      parser.new.parse("a, b - c")
    }.to raise_error(Whittle::ParseError)
  end

  it "provides access to the line number" do
      parser.new.parse("a, \nb, \nc- \nd")
    begin
      parser.new.parse("a, \nb, \nc- \nd")
    rescue Whittle::ParseError => e
      e.line.should == 3
    end
  end

  it "provides access to the expected tokens" do
    begin
      parser.new.parse("a, \nb, \nc- \nd")
    rescue Whittle::ParseError => e
      e.expected.should == [","]
    end
  end

  it "provides access to the received token" do
    begin
      parser.new.parse("a, \nb, \nc- \nd")
    rescue Whittle::ParseError => e
      e.received.should == "-"
    end
  end
end
