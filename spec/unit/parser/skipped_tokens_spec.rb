require "spec_helper"

describe "a parser that skips tokens" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:wsp => /\s+/).skip!

      rule("-") % :left

      rule(:int => /[0-9]+/).as { |int| Integer(int) }

      rule(:expr) do |r|
        r[:expr, "-", :expr].as { |a, _, b| a - b }
        r[:int]
      end

      start(:expr)
    end
  end

  it "reads the input excluding the skipped tokens" do
    parser.new.parse("6 - 3 - 1").should == 2
  end
end
