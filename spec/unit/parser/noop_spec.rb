require "spec_helper"

describe "a noop parser" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule(:char => /./)

      rule(:prog) do |r|
        r[:char].skip!
      end

      start(:prog)
    end
  end

  it "returns nil for all inputs" do
    ["a", "b"].each do |input|
      parser.new.parse(input).should be_nil
    end
  end
end
