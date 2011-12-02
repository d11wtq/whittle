# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # Represents an terminal Rule, matching a pattern in the input String
  class Terminal < Rule
    def initialize(name, *components)
      super

      pattern = @components.first

      @pattern = if pattern.kind_of?(Regexp)
        Regexp.new("\\G#{pattern}")
      else
        Regexp.new("\\G#{Regexp.escape(pattern)}")
      end
    end

    # Hard-coded to always return true
    def terminal?
      true
    end

    # Invoked for terminal rules during lexing, ignored for nonterminal rules.
    #
    # @param [String] source
    #   the input String the scan
    #
    # @param [Fixnum] offset
    #   the current index in the search
    #
    # @param [Fixnum] line
    #   the line the lexer was up to when the previous token was matched
    #
    # @return [Hash]
    #   a Hash representing the token, containing :rule, :value, :line and
    #   :discarded, if the token is to be skipped.
    #
    # Returns nil if nothing is matched.
    def scan(source, offset, line)
      if match = source.match(@pattern, offset)
        {
          :rule      => self,
          :value     => match[0],
          :line      => line + match[0].count("\r\n", "\n"),
          :discarded => @action.equal?(NULL_ACTION)
        }
      end
    end
  end
end
