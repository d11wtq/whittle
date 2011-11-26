# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # RuleSets are named collections of Rules.
  #
  # When you use the name of a rule in the grammar, you actually refer to the
  # entire RuleSet and not an individual rule within it (unless of course, it
  # only contains one Rule)
  class RuleSet
    include Enumerable

    # Create a new RuleSet named +name+.
    #
    # @param [Symbol, String] name
    #   the name of the rule in the grammar
    def initialize(name)
      @name  = name
      @rules = []
    end

    # Enumerate all Rules in the set.
    def each(&block)
      @rules.each(&block)
    end

    # Add a new Rule to the set.
    #
    # @param [Object...] components...
    #   a variable list of components (Symbols, Strings, or Regexps)
    def [](*components)
      Rule.new(@name, *components).tap do |rule|
        @rules << rule
      end
    end

    # Invoked during lexing, delegating to each rule in the set.
    #
    # @param [String] source
    #   the complete input string
    #
    # @param [Fixnum] line
    #   the current line number
    #
    # @return [Hash]
    #   a Hash representing the found token, or nil
    def scan(source, line)
      each do |rule|
        if token = rule.scan(source, line)
          return token
        end
      end

      nil
    end

    # Recursively builds the parse table into +table+.
    #
    # @param [Hash<Fixnum,Hash>] table
    #   the parse table as constructed so far
    #
    # @param [Parser] parser
    #   the parser containing the grammar
    #
    # @param [Hash] context
    #   a Hash used to track state when building the parse table
    #
    # @return [Hash]
    #   the parse table
    def build_parse_table(table, parser, context)
      return table if context[:seen].include?([context[:state], self])

      context[:seen] << [context[:state], self]

      table.tap do
        each do |rule|
          rule.build_parse_table(table, parser, context)
        end
      end
    end

    # Predicate test for whether or not this RuleSet references a single
    # terminal Symbol.
    #
    # @return [Boolean]
    #   true if this rule is a terminal symbol
    def terminal?
      @rules.length == 1 && @rules.first.terminal?
    end

    # Predicate test for whether or not this RuleSet references a nonterminal Symbol.
    #
    # @return [Boolean]
    #   true if this rule is a nonterminal symbol
    def nonterminal?
      !terminal?
    end

    # Convenience method to access the precedence of a RuleSet representing a terminal.
    #
    # @return [Fixnum]
    #   the precedence of the terminal Symbol, or zero for nonterminals.
    def prec
      terminal? ? @rules.first.prec : 0
    end

    # Convenience method to access the associativity of a RuleSet representing a terminal.
    #
    # @return [Symbol]
    #   the associativty of the terminal Symbol.
    def assoc
      terminal? ? @rules.first.assoc : :right
    end
  end
end
