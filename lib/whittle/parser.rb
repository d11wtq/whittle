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
  # very powerful and it is generally said that the languages they cannot parse are difficult for
  # humans to understand.
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
      # The are two ways to call this method.  The most fundamental way is to pass a Symbol
      # in the +name+ parameter, along with a block, in which you will add one more possible
      # rules.
      #
      # @example Specifying multiple rules with a block
      #
      #   rule(:expr) do |r|
      #     r[:expr, "+", :expr].as { |a, _, b| a + b }
      #     r[:expr, "-", :expr].as { |a, _, b| a - b }
      #     r[:expr, "/", :expr].as { |a, _, b| a / b }
      #     r[:expr, "*", :expr].as { |a, _, b| a * b }
      #     r[:integer].as { |i| Integer(i) }
      #   end
      #
      # Each rule specified in this way defines one of many possibilities to describe the input.
      # Rules may refer back to themselves, which means in the above, any integer is a valid
      # expr:
      #
      #   42
      #
      # Therefore any sum of integers as also a valid expr:
      #
      #   42 + 24
      #
      # Therefore any multiplication of sums of integers is also a valid expr, and so on.
      #
      #   42 + 24 * 7 + 52
      #
      # A rule like the above is called a 'nonterminal', because upon recognizing any expr, it
      # is possible for the rule to continue collecting input and becoming a larger expr.
      #
      # In subtle contrast, a rule like the following:
      #
      #   rule("+") do |r|
      #     r["+"].as { |plus| plus }
      #   end
      #
      # Is called a 'terminal' token, since upon recognizing a "+", the parser cannot
      # add further input to the "+" itself... it is the tip of a branch in the parse tree; the
      # branch terminates here, and subsequently the rule is terminal.
      #
      # There is a shorthand way to write the above rule:
      #
      #   rule("+")
      #
      # Not given a block, #rule treats the name parameter as a literal token.
      #
      # Note that nonterminal rules are composed of other nonterminal rules and/or terminal
      # rules.  Terminal rules contain one, and only one Regexp pattern or fixed string.
      #
      # @param [Symbol, String] name
      #   the name of the ruleset (note the one ruleset can contain multiple rules)
      #
      # @return [RuleSet, Rule]
      #   the newly created RuleSet if a block was given, otherwise a rule representing a
      #   terminal token for the input string +name+.
      def rule(name)
        rules[name] = RuleSet.new(name)

        if block_given?
          rules[name].tap { |r| yield r }
        else
          rules[name][name].as(:value)
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
        raise "Undefined start rule #{start.inspect}" unless rules.key?(start)

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

                  return accept(args.pop) if states.length == 1 && token[:name] == :$end
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
      source = input.dup
      line   = 1

      until source.length == 0 do
        next_token(source, line).tap do |token|
          raise "Unmatched input #{source.inspect} on line #{line}" if token.nil?

          line = token[:line]
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
      message = <<-ERROR.gsub(/\n\s+/, " ").strip
      Parse error:
      expected
      #{state.keys.map { |k| k.inspect }.join("; or ")}
      but got
      #{input[:name].inspect}
      on line
      #{input[:line]}
      ERROR

      raise message
    end

    private

    def next_token(source, line)
      rules.each do |name, rule|
        if token = rule.scan(source, line)
          token[:name] = name
          return token
        end
      end

      nil
    end

    def accept(tree)
      tree[:rule].action.call(*tree[:args].map { |arg| Hash === arg ? accept(arg) : arg })
    end
  end
end
