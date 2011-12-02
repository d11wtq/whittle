# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # Represents an terminal Rule, matching a pattern in the input String
  class Terminal < Rule
    def terminal?
      true
    end
  end
end
