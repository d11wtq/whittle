require "spec_helper"

describe "a parser with two terminal rules which overlap" do
  let(:parser) do
    Class.new(Whittle::Parser) do
      rule("def")
      rule("define")
      rule(:id => /[a-z_]+/)

      rule(:prog) do |r|
        r["def"]
        r["define"]
        r[:id]
      end

      start(:prog)
    end
  end

  it "uses the longest match" do
    parser.new.parse("define_method").should == "define_method"
  end
end
