# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # UnconsumedInputError is raised if the lexical analyzer itself cannot find any tokens.
  class UnconsumedInputError < Error
  end
end
