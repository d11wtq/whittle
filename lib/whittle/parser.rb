# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # Parsers are created by subclassing the Parser class and defining a context-free grammar.
  #
  # Unlike other LALR(1) parsers, Whittle does not rely on code-generation, instead it
  # synthesizes a parse table from the grammar at runtime, on the first parse.
  #
  # While Whittle's implementation works a little differently to yacc/bison and ruby parser
  # generators like racc and citrus, the parseable grammars are the same.  LALR(1) parsers are
  # very powerful and it is generally said that the languages they cannot parse are difficult
  # for humans to understand.
  #
  # You should refer to the README for a full description of how to use the parser,
  # but a quick example follows.
  #
  # @example A simple Whittle Parser
  #
  #   class Calculator < Whittle::Parser
  #     rule(:wsp => /\s+/).skip!
  #
  #     rule(:int => /[0-9]+/).as { |i| Integer(i) }
  #
  #     rule("+") % :left ^ 1
  #     rule("-") % :left ^ 1
  #     rule("/") % :left ^ 2
  #     rule("*") % :left ^ 2
  #
  #     rule(:expr) do |r|
  #       r[:expr, "+", :expr].as { |left, _, right| left + right }
  #       r[:expr, "-", :expr].as { |left, _, right| left - right }
  #       r[:expr, "/", :expr].as { |left, _, right| left / right }
  #       r[:expr, "*", :expr].as { |left, _, right| left * right }
  #       r[:int]
  #     end
  #
  #     start(:expr)
  #   end
  #
  #   calculator = Calculator.new
  #   calculator.parse("1 + (2 * 6) - 7")
  #   # => 6
  class Parser
    class << self
      # Returns a Hash mapping rule names with their RuleSets.
      #
      # @return [Hash<String, RuleSet>]
      #   all rules defined by the parser
      def rules
        @rules ||= {}
      end

      # Declares a new rule.
      #
      # The are three ways to call this method:
      #
      #  1. rule("+")
      #  2. rule(:int => /[0-9]+/)
      #  3. rule(:expr) do |r|
      #       r[:int, "+", :int].as { |a, _, b| a + b }
      #     end
      #
      # Variants (1) and (2) define basic terminal symbols (direct chunks of the input string),
      # while variant (3) takes a block to define one or more nonterminal rules.
      #
      # @param [Symbol, String, Hash] name
      #   the name of the rule, or a Hash mapping the name to a pattern
      #
      # @return [RuleSet, Rule]
      #   the newly created RuleSet if a block was given, otherwise a rule representing a
      #   terminal token for the input string +name+.
      def rule(name)
        if block_given?
          raise ArgumentError,
            "Parser#rule does not accept both a Hash and a block" if name.kind_of?(Hash)

          rules[name] = RuleSet.new(name, false)
          rules[name].tap { |r| yield r }
        else
          key, value = if name.kind_of?(Hash)
            raise ArgumentError,
              "Only one element allowed in Hash for Parser#rule" unless name.length == 1

            name.first
          else
            [name, name]
          end

          rules[key] = RuleSet.new(key, true)
          rules[key][value].as(:value)
        end
      end

      # Declares most general rule that can be used to describe an entire input.
      #
      # Called without any arguments, returns the current start rule.
      #
      # @param [Symbol] name
      #   the name of a rule defined in the parser (does not need to be defined beforehand)
      #
      # @return [Symbol]
      #   the new (or current) start rule
      def start(name = nil)
        @start = name unless name.nil?
        @start
      end

      # Returns the entire parse table used to interpret input into the parser.
      #
      # You should not need to call this method, though you may wish to inspect its contents
      # during debugging.
      #
      # Note that the token +nil+ in the parse table represents "anything" and its action is
      # always to reduce.
      #
      # Shift-reduce conflicts are resolved at runtime and therefore remain in the parse table.
      #
      # @return [Hash]
      #   a 2-dimensional Hash representing states with actions to perform for a given lookahead
      def parse_table
        @parse_table ||= parse_table_for_rule(start)
      end

      # Prepare the parse table for a given rule instead of the start rule.
      #
      # Warning: this method does not memoize the result, so you should not use it in production.
      #
      # @param [Symbol, String] name
      #   the name of the Rule to use as the start rule
      #
      # @return [Hash]
      #   the complete parse table for this rule
      def parse_table_for_rule(name)
        raise GrammarError, "Undefined start rule #{name.inspect}" unless rules.key?(name)

        rule = if rules[name].terminal?
          RuleSet.new(:$start, false).tap { |r| r[name].as { |prog| prog } }
        else
          rules[name]
        end

        rule.build_parse_table(
          {},
          self,
          {
            :initial => true,
            :state   => [rule, 0].hash,
            :seen    => [],
            :offset  => 0,
            :prec    => 0
          }
        )
      end
    end

    # Alias for class method Parser.rules
    #
    # @see Parser.rules
    def rules
      self.class.rules
    end

    # Accepts input in the form of a String and attempts to parse it according to the grammar.
    #
    # The input is scanned using a lexical analysis routine, defined by the #lex method. Each
    # token detected by the routine is used to pick an action from the parse table.
    #
    # Each time a sequence of inputs has been read that concludes a rule in the grammar, the
    # inputs are passed as arguments to the block for that rule, converting the sequence into
    # single input before the parse continues.
    #
    # If the parser encounters a token it does not expect, a parse error will be raised,
    # specifying what was expected, what was received, and on which line the error occurred.
    #
    # A successful parse returns the result of evaluating the start rule, whatever that may be.
    #
    # It is possible to specify a different start rule during development.
    #
    # @example Using a different start rule
    #
    #   parser.parse(str, :rule => :another_rule)
    #
    # @param [String] input
    #   a complete input string to parse according to the grammar
    #
    # @param [Hash] options
    #   currently the only supported option is :rule, to specify a different once-off start rule
    #
    # @return [Object]
    #   whatever the grammar defines
    def parse(input, options = {})
      table  = if options.key?(:rule)
        self.class.parse_table_for_rule(options[:rule])
      else
        self.class.parse_table
      end

      states = [table.keys.first]
      args   = []
      line   = 1

      lex(input) do |token|
        line  = token[:line]

        loop do
          state = table[states.last]

          if instruction = state[token[:name]] || state[nil]
            case instruction[:action]
            when :shift
              states << instruction[:state]
              args   << token[:rule].action.call(token[:value])
              break
            when :reduce, :accept
              rule = instruction[:rule]
              size = rule.components.length
              args << rule.action.call(*args.pop(size))
              states.pop(size)

              if states.length == 1 && instruction[:action] == :accept
                return args.pop
              elsif goto = table[states.last][rule.name]
                states << goto[:state]
                next
              end
            end
          end

          error(state, token, :input => input, :states => states, :args => args)
        end
      end
    end

    # Accepts a String as input and repeatedly yields terminal tokens found in the grammar.
    #
    # The last token yielded is always named :$end and has the value of +nil+.
    #
    # You may override this method to define a smarter implementation, should you need to.
    #
    # @param [String] input
    #   the complete input string the lex
    def lex(input)
      line   = 1
      offset = 0
      ending = input.length

      until offset == ending do
        next_token(input, offset, line).tap do |token|
          raise UnconsumedInputError,
            "Unmatched input #{input[offset..-1].inspect} on line #{line}" if token.nil?

          token[:offset] = offset
          line, token[:line] = token[:line], line
          offset += token[:value].length
          yield token unless token[:discarded]
        end
      end

      yield ({ :name => :$end, :line => line, :value => nil, :offset => offset })
    end

    # Invoked when the parser detects an error.
    #
    # The default implementation raises a RuntimeError specifying the allowed inputs
    # and the received input, along with a line number.
    #
    # You may override this method with your own implementation, which, at least in theory,
    # can recover from the error and allow the parse to continue, though this is an extremely
    # advanced topic and requires a good understanding of how LALR(1) parsers operate.
    #
    # @param [Hash] state
    #   the possible actions for the current parser state
    #
    # @param [Hash] token
    #   the received token
    #
    # @param [Hash] context
    #   the current parse context (input + arg stack + state stack)
    def error(state, token, context)
      raise ParseErrorBuilder.exception(state, token, context)
    end

    private

    def next_token(source, offset, line)
      best = nil

      rules.each do |name, rule|
        next unless rule.terminal?

        if token = rule.scan(source, offset, line)
          best ||= token
          token[:name] = name
          best = token if token[:value].length > best[:value].length
        end
      end

      best
    end
  end
end
