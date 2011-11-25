require "spec_helper"

describe "a type-casting parser" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:int) do |r|
        r[/[0-9]+/].as { |int| Integer(int) }
      end

      start(:int)
    end
  end

  it "returns the input passed through the callback" do
    parser.new.parse("123").should == 123
  end
end
