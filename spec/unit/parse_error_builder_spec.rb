require "spec_helper"

describe Whittle::ParseErrorBuilder do
  let(:context) do
    {
      :input => "one two three four five\nsix seven eight nine ten\neleven twelve"
    }
  end

  let(:state) do
    {
      "gazillion" => { :action => :shift, :state => 7 }
    }
  end

  context "given an error region in the middle of a line" do
    let(:token) do
      {
        :name   => "eight",
        :value  => "eight",
        :offset => 34
      }
    end

    let(:indicator) do
      Regexp.escape(
        "six seven eight nine ten\n" <<
        "      ... ^ ..."
      )
    end

    it "indicates the exact region" do
      Whittle::ParseErrorBuilder.exception(state, token, context).message.should =~ /#{indicator}/
    end
  end

  context "given an error region near the start of a line" do
    let(:token) do
      {
        :name   => "two",
        :value  => "two",
        :offset => 4
      }
    end

    let(:indicator) do
      Regexp.escape(
        "one two three four five\n" <<
        "    ^ ..."
      )
    end

    it "indicates the exact region" do
      Whittle::ParseErrorBuilder.exception(state, token, context).message.should =~ /#{indicator}/
    end
  end

  context "given an error region near the end of a line" do
    let(:token) do
      {
        :name   => "five",
        :value  => "five",
        :offset => 19
      }
    end

    let(:indicator) do
      Regexp.escape(
        "one two three four five\n" <<
        "               ... ^ ..."
      )
    end

    it "indicates the exact region" do
      Whittle::ParseErrorBuilder.exception(state, token, context).message.should =~ /#{indicator}/
    end
  end
end
