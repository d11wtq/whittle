# Whittle: A very small LALR(1) parser in pure ruby; not a yacc clone.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # Parsers are created at runtime, by subclassing the Parser class.
  #
  # Unlike other LALR(1) parsers, Whittle parsers do not rely on code-generation,
  # instead they synthesize a parse table from the grammar at runtime, on the first
  # parse.
  #
  # While Whittle's implementation works a little differently to yacc/bison and
  # ruby parser generators like racc, the parseable grammars are the same.  LALR(1)
  # parsers are very powerful.
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
  #       r[/[0-9]+/].as_value
  #     end
  #
  #     rule(:operator) do |r|
  #       r["+"].as_value % :left
  #       r["-"].as_value % :left
  #       r["/"].as_value % :left
  #       r["*"].as_value % :left
  #     end
  #
  #     rule(:expr) do |r|
  #       r[:expr, "+", :expr].as { |left, _, right| left + right }
  #       r[:expr, "-", :expr].as { |left, _, right| left - right }
  #       r[:expr, "/", :expr].as { |left, _, right| left / right }
  #       r[:expr, "*", :expr].as { |left, _, right| left * right }
  #       r[:int].as_value
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
      # @return [RuleSet]
      #   all rules defined by the parser
      def rules
        @rules ||= {}
      end

      # Declares a new rule with +name+.
      #
      # The RuleSet associated with the rule is yielded.  You must specify the grammar
      # within the block.
      #
      # @example Declaring a new rule
      #
      #   rule(:func_call) do |r|
      #     r[:identifier, "(", :arg_list, ")"].as { |id, _, args, _| Context.current.call_function(id, *args) }
      #   end
      #
      # @param [Symbol] name
      #   the name of the ruleset (note the one ruleset can contain multiple rules)
      #
      # @return [RuleSet]
      #   the newly created RuleSet
      def rule(name)
        raise ArgumentError, "Parser.rule requires a block, but none was given" unless block_given?

        RuleSet.new(name).tap do |rule_set|
          rules[name] = rule_set
          yield rule_set
        end
      end

      # Declare most general rule that can be used to describe an entire input.
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

      # Returns the numeric value for the initial state (the state ID associated with the start rule).
      #
      # In most LALR(1) parsers, this would be zero, but for implementation reasons, this will be an
      # unpredictably large (or small) number.
      #
      # @return [Fixnum]
      #   the ID for the initial state in the parse table
      def initial_state
        prepare_start_rule
        [rules[@start], 0].hash
      end

      # Returns the entire parse table used to interpret input into the parser.
      #
      # You should not need to call this method, though you may wish to inspect its contents during debugging.
      #
      # Note that the token +nil+ in the parse table represents "any symbol" and its action is always reduce.
      # Shift-reduce conflicts are resolved at runtime and therefore remain in the parse table.
      #
      # @return [Hash]
      #   a 2-dimensional Hash representing a series of states and actions to perform for a given lookahead
      def parse_table
        prepare_start_rule
        rules[@start].build_parse_table(initial_state, {}, self)
      end

      private

      def prepare_start_rule
        raise "Undefined start rule #{@start.inspect}" unless rules.key?(@start)

        if rules[@start].terminal?
          rule(:*) do |r|
            r[@start].as { |prog| prog }
          end

          @start = :*
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
    # The input is scanned using a lexical analysis routine, defined by the #lex method. Each token
    # detected by the routine is used to pick an action from the parse table.  Each reduction initially
    # builds a branch in an AST (abstract syntax tree), until all input has been read and the start
    # rule has been recognized, at which point the AST is evaluated by invoking the callbacks defined in
    # the grammar in a depth-first fashion.
    #
    # If the parser encounters a token it does not recognise, a parse error will be raised, specifying
    # what was expected, what was received, and on which line the error occurred.
    #
    # A successful parse returns the result of evaluating the start rule.
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
            return accept(args.pop) if states.length == 1 && token[:name] == :$end

            state = table[states.last]

            if ins = instruction(state, input)
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
                when :goto
                  input = token
                  states << ins[:state]
              end
            else
              parse_error(state, input)
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
    # @param [Hash] context
    #   the current parse context (input stack + state stack)
    def parse_error(state, input)
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

    def instruction(state, input)
      # FIXME: I think this method does work the parse table should really do
      #
      # The parse table should:
      # a) Disallow string rules, resolving them to valid rule names
      # b) Upon adding a new transition, invoke a resolve_conflicts method
      #
      # resolve_conflicts does:
      #
      # 1. If there exists a reduce rule, for all rules tagged %left, set their actions to the reduce
      # 2. Upon processing (1), leave shift as the default action if the current symbol has a lower prec than the lookahead
      # 3. Not sure about nonassoc, but it's most like a standard parse error

      assoc     = input[:rule].assoc unless input[:name] == :$end
      reduce_op = state[nil]
      shift_op  = state[input[:name]] || state[input[:value]]

      case assoc
        when :left  then reduce_op || shift_op
        when :right then shift_op  || reduce_op
        when nil    then shift_op  || reduce_op
        when :nonassoc
          if shift_op && reduce_op
            raise "Ambiguous use of non-associative #{input[:name].inspect} on line #{input[:line]}"
          else
            shift_op || reduce_op
          end
      end
    end

    def accept(tree)
      tree[:rule].action.call(*tree[:args].map { |arg| Hash === arg ? accept(arg) : arg })
    end
  end
end
