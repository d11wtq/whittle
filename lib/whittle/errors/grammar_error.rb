# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # GrammarError is raised if the developer defines an incorrect grammar.
  class GrammarError < Error
  end
end
