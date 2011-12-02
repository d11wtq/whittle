# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # Represents an nonterminal Rule, which refers to other Rules.
  class NonTerminal < Rule
    def terminal?
      false
    end
  end
end
