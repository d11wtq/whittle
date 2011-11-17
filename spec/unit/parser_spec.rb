require "spec_helper"

describe Whittle::Parser do
  context "given no-op program" do
    let(:parser) do
      Class.new(Whittle::Parser) do
        rule(:char) do |r|
          r[/./].as { |chr| chr }
        end

        rule(:prog) do |r|
          r[:prog, :char]
          r[:char]
        end

        start(:prog)
      end
    end

    it "returns nil for all inputs" do
      pending "I'm undecided on if this should be allowed"

      ["a b c", "a (b) > *c"].each do |input|
        parser.new.parse(input).should be_nil
      end
    end
  end

  context "given a program returning its input" do
    let(:parser) do
      Class.new(Whittle::Parser) do
        rule(:foo) do |r|
          r["FOO"].as { |str| str }
        end

        start(:foo)
      end
    end

    context "for matching input" do
      it "returns the input" do
        parser.new.parse("FOO").should == "FOO"
      end
    end
  end

  context "given a program returning an integer" do
    let(:parser) do
      Class.new(Whittle::Parser) do
        rule(:int) do |r|
          r[/[0-9]+/].as { |int| Integer(int) }
        end

        start(:int)
      end
    end

    context "for matching input" do
      it "returns the input as an integer" do
        parser.new.parse("123").should == 123
      end
    end
  end

  context "given a program returning the sum of two integers" do
    let(:parser) do
      Class.new(Whittle::Parser) do
        rule(:int) do |r|
          r[/[0-9]+/].as { |int| Integer(int) }
        end

        rule(:sum) do |r|
          r[:int, "+", :int].as { |a, _, b| a + b }
        end

        rule(:default) do |r|
          r[/./].as { |c| c }
        end

        start(:sum)
      end
    end

    context "for matching input" do
      it "returns the sum of the operands" do
        parser.new.parse("10+20").should == 30
      end
    end
  end
end
