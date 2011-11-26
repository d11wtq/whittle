# Whittle: A little LALR(1) parser in pure ruby, without a generator.
#
# Copyright (c) Chris Corbyn, 2011

module Whittle
  # Represents an individual Rule, forming part of an overall RuleSet.
  class Rule
    NULL_ACTION = Proc.new { }
    DUMP_ACTION = Proc.new { |input| input }

    # Returns the name of the RuleSet in which this Rule is used
    attr_reader :name

    # Returns a Proc used to reduce the input for the Rule
    attr_reader :action

    # Returns an Array of the sequence of inputs that form this Rule
    attr_reader :components

    # Returns the associativity of this Rule (:left, :right or :nonassoc)
    attr_reader :assoc

    # Returns the precedency of this Rule, as an integer (higher means stronger)
    attr_reader :prec

    # Create a new Rule for the RuleSet named +name+.
    #
    # The components can either be names of other Rules, or for a terminal Rule,
    # a single pattern to match in the input string.
    #
    # @param [String] name
    #   the name of the RuleSet to which this Rule belongs
    #
    # @param [Object...] components...
    #   a variable list of components that make up the Rule
    def initialize(name, *components)
      @components = components
      @action     = NULL_ACTION
      @name       = name
      @terminal   = components.length == 1 && !components.first.kind_of?(Symbol)
      @assoc      = :right
      @prec       = 0

      @components.each do |c|
        unless Regexp === c || String === c || Symbol === c
          raise ArgumentError, "Unsupported rule component #{c.class}"
        end
      end

      pattern = @components.first

      if @terminal
        @pattern = if pattern.kind_of?(Regexp)
          Regexp.new("^#{pattern}")
        else
          Regexp.new("^#{Regexp.escape(pattern)}")
        end
      end
    end

    # Predicate check for  whether or not the Rule represents a terminal symbol.
    #
    # A terminal symbol is effectively any rule that directly matches some
    # pattern in the input string and references no other rules.
    #
    # @return [Boolean]
    #   true if this rule represents a terminal symbol
    def terminal?
      @terminal
    end

    # Walks all possible branches from the given rule, building a parse table.
    #
    # The parse table is a list of instructions (transitions) that can be looked
    # up, given the current parser state and the current lookahead token.
    #
    # @param [Hash<Fixnum,Hash>] table
    #   the table to construct for
    #
    # @param [Parser] parser
    #   the Parser containing all the Rules in the grammar
    #
    # @param [Hash] context
    #   a Hash used to track state as the grammar is analyzed
    def build_parse_table(table, parser, context)
      state      = table[context[:state]] ||= {}
      sym        = components[context[:offset]]
      rule       = parser.rules[sym]
      new_offset = context[:offset] + 1
      new_state  = if state.key?(sym)
        state[sym][:state]
      end || [self, new_offset].hash

      if sym.nil?
        state[sym] = {
          :action => :reduce,
          :rule   => self,
          :prec   => context[:prec]
        }
      else
        raise "Unreferenced rule #{sym.inspect}" if rule.nil?

        if rule.terminal?
          state[sym] = {
            :action => :shift,
            :state  => new_state,
            :prec   => [rule.first.prec, context[:prec]].max
          }
        else
          state[sym] = {
            :action => :goto,
            :state  => new_state
          }

          rule.build_parse_table(
            table,
            parser,
            {
              :state  => context[:state],
              :seen   => context[:seen],
              :offset => 0,
              :prec   => 0
            }
          )
        end

        build_parse_table(
          table,
          parser,
          {
            :state  => new_state,
            :seen   => context[:seen],
            :offset => new_offset,
            :prec   => context[:prec]
          }
        )
      end

      resolve_conflicts(state, parser)
    end

    # Specify how this Rule should be reduced.
    #
    # Given a block, the Rule will be reduced by passing the result of reducing
    # all inputs as arguments to the block.
    #
    # Given the Symbol :value, the matched input will be returned verbatim.
    # Given the Symbol :nothing, nil will be returned; you can use this to
    # skip whitesapce and comments, for example.
    #
    # @param [Symbol] preset
    #   one of the preset actions, :value or :nothing; optional
    #
    # @return [Rule]
    #   returns self
    def as(preset = nil, &block)
      tap do
        case preset
          when :value   then @action = DUMP_ACTION
          when :nothing then @action = NULL_ACTION
          when nil
            raise ArgumentError, "Rule#as expected a block, not none given" \
              unless block_given?
            @action = block
          else
            raise ArgumentError, "Invalid preset #{preset.inspect} to Rule#as"
        end
      end
    end

    # Set the associativity of this Rule.
    #
    # Accepts values of :left, :right (default) or :nonassoc.
    #
    # @param [Symbol] assoc
    #   one of :left, :right or :nonassoc
    #
    # @return [Rule]
    #   returns self
    def %(assoc)
      raise "Invalid associativity #{assoc.inspect}" \
        unless [:left, :right, :nonassoc].include?(assoc)

      tap { @assoc = assoc }
    end

    # Set the precedence of this Rule, as an Integer.
    #
    # The higher the number, the higher the precedence.
    #
    # @param [Fixnum] prec
    #   the precedence (default is zero)
    def ^(prec)
      tap { @prec = prec.to_i }
    end

    # Invoked for terminal rules during lexing, ignored for nonterminal rules.
    #
    # @param [String] source
    #   the input String the scan
    #
    # @param [Fixnum] line
    #   the line the lexer was up to when the previous token was matched
    #
    # @return [Hash]
    #   a Hash representing the token, containing :rule, :value, :line and
    #   :discarded, if the token is to be skipped.
    #
    # Returns nil if nothing is matched.
    def scan(source, line)
      return nil unless @terminal

      copy = source.dup
      if match = copy.slice!(@pattern)
        source.replace(copy)
        {
          :rule      => self,
          :value     => match,
          :line      => line + ("~" + match + "~").lines.count - 1,
          :discarded => @action.equal?(NULL_ACTION)
        }
      end
    end

    private

    def resolve_conflicts(instructions, parser)
      if r = instructions.detect { |s, i| i[:action] == :reduce }
        instructions.reject! do |s, i|
          i[:action] == :shift &&
            parser.rules[s].first.assoc == :left &&
            i[:prec] <= r.last[:prec]
        end
      end
    end
  end
end
