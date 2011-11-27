# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # All exceptions descend from this one.
  class Error < RuntimeError
  end
end
