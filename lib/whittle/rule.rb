module Whittle
  class Rule
    NULL_ACTION = Proc.new { }
    DUMP_ACTION = Proc.new { |input| input }

    attr_reader :name
    attr_reader :action
    attr_reader :components
    attr_reader :assoc
    attr_reader :prec

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

        if components.length > 1 && Regexp === c
          raise ArgumentError, "Nonterminal rules (rules with more than one component) may not contain regular expressions"
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

    def terminal?
      @terminal
    end

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

    def as(&block)
      raise ArgumentError, "Rule#as requires a block, but none given" \
        unless block_given?

      tap do
        @action = block
      end
    end

    def as_value
      as(&DUMP_ACTION)
    end

    def %(assoc)
      raise "Invalid associativity #{assoc.inspect}" \
        unless [:left, :right, :nonassoc].include?(assoc)

      tap { @assoc = assoc }
    end

    def ^(prec)
      tap { @prec = prec.to_i }
    end

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
