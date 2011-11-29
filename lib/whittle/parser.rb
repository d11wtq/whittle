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
  #     rule(:wsp) do |r|
  #       r[/s+/] # skip whitespace
  #     end
  #
  #     rule(:int) do |r|
  #       r[/[0-9]+/].as { |i| Integer(i) }
  #     end
  #
  #     rule("+") % :left
  #     rule("-") % :left
  #     rule("/") % :left
  #     rule("*") % :left
  #
  #     rule(:expr) do |r|
  #       r[:expr, "+", :expr].as { |left, _, right| left + right }
  #       r[:expr, "-", :expr].as { |left, _, right| left - right }
  #       r[:expr, "/", :expr].as { |left, _, right| left / right }
  #       r[:expr, "*", :expr].as { |left, _, right| left * right }
  #       r[:int].as(:value)
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

          rules[name] = RuleSet.new(name)
          rules[name].tap { |r| yield r }
        else
          key, value = if name.kind_of?(Hash)
            raise ArgumentError,
              "Only one element allowed in Hash for Parser#rule" unless name.length == 1

            name.first
          else
            [name, name]
          end

          rules[key] = RuleSet.new(key)
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

      # Returns the numeric value for the initial state (the state ID associated with the start
      # rule).
      #
      # In most LALR(1) parsers, this would be zero, but for implementation reasons, this will
      # be an unpredictably large (or small) number.
      #
      # @return [Fixnum]
      #   the ID for the initial state in the parse table
      def initial_state
        prepare_start_rule
        [rules[start], 0].hash
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
        @parse_table ||= begin
          prepare_start_rule
          rules[start].build_parse_table(
            {},
            self,
            {
              :state  => initial_state,
              :seen   => [],
              :offset => 0,
              :prec   => 0
            }
          )
        end
      end

      private

      def prepare_start_rule
        raise GrammarError, "Undefined start rule #{start.inspect}" unless rules.key?(start)

        if rules[start].terminal?
          rule(:*) do |r|
            r[start].as { |prog| prog }
          end

          start(:*)
        end
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
    # token detected by the routine is used to pick an action from the parse table.  Each
    # reduction initially builds a branch in an AST (abstract syntax tree), until all input has
    # been read and the start rule has been recognized, at which point the AST is evaluated by
    # invoking the callbacks defined in the grammar in a depth-first fashion.
    #
    # If the parser encounters a token it does not recognise, a parse error will be raised,
    # specifying what was expected, what was received, and on which line the error occurred.
    #
    # A successful parse returns the result of evaluating the start rule, whatever that may be.
    #
    # @param [String] input
    #   a complete input string to parse according to the grammar
    #
    # @return [Object]
    #   whatever the grammar defines
    def parse(input)
      table  = self.class.parse_table
      states = [self.class.initial_state]
      args   = []
      line   = 1

      lex(input) do |token|
        line  = token[:line]
        input = token

        catch(:shifted) do
          loop do
            state = table[states.last]

            if ins = state[input[:name]] || state[nil]
              case ins[:action]
                when :shift
                  input[:args] = [input.delete(:value)]
                  states << ins[:state]
                  args << input
                  throw :shifted
                when :reduce
                  size = ins[:rule].components.length
                  input = {
                    :rule => ins[:rule],
                    :name => ins[:rule].name,
                    :line => line,
                    :args => args.pop(size)
                  }
                  states.pop(size)
                  args << input

                  if states.length == 1 && token[:name] == :$end
                    return accept(args.pop)
                  elsif !table[states.last][input[:name]]
                    # FIXME: This duplicate goto check is a a bug in the algorithm
                    error(state, token, :states => states, :args => args)
                  end
                when :goto
                  input = token
                  states << ins[:state]
              end
            else
              error(state, input, :states => states, :args => args)
            end
          end
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

          offset += token[:value].length
          line, token[:line] = token[:line], line
          yield token unless token[:discarded]
        end
      end

      yield ({ :name => :$end, :line => line, :value => nil })
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
    # @param [Hash] input
    #   the received token (or, unlikely, a nonterminal symbol)
    #
    # @param [Hash] stack
    #   the current parse context (arg stack + state stack)
    def error(state, input, stack)
      expected = extract_expected_tokens(state)
      message  = <<-ERROR.gsub(/\n\s+/, " ").strip
        Parse error:
        expected
        #{expected.map { |k| k.inspect }.join("; or ")}
        but got
        #{input[:name].inspect}
        on line
        #{input[:line]}
      ERROR

      raise ParseError.new(message, input[:line], expected, input[:name])
    end

    private

    def next_token(source, offset, line)
      rules.each do |name, rule|
        if token = rule.scan(source, offset, line)
          token[:name] = name
          return token
        end
      end

      nil
    end

    def extract_expected_tokens(state)
      state.reject { |s, i| i[:action] == :goto }.keys.collect { |k| k.nil? ? :$end : k }
    end

    def accept(tree)
      tree[:rule].action.call(*tree[:args].map { |arg| Hash === arg ? accept(arg) : arg })
    end
  end
end
