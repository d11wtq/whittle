require "spec_helper"

describe "a parser that skips tokens" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:wsp) do |r|
        r[/\s+/]
      end

      rule("-") % :left

      rule(:int) do |r|
        r[/[0-9]+/].as { |int| Integer(int) }
      end

      rule(:expr) do |r|
        r[:expr, "-", :expr].as { |a, _, b| a - b }
        r[:int].as_value
      end

      start(:expr)
    end
  end

  it "reads the input excluding the skipped tokens" do
    parser.new.parse("6 - 3 - 1").should == 2
  end
end
