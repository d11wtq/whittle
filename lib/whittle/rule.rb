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

    # Recursively builds a 2-dimensional parse table starting with the current rule
    # The declaration of this method is complex (it has too many parameters), so is
    # likely to change at some point.
    def build_parse_table(state, table, parser, seen, offset = 0, prec = 0)
      table[state] ||= {}
      sym        = components[offset]
      rule       = parser.rules[sym]
      new_offset = offset + 1
      new_state  = if table[state].key?(sym)
        table[state][sym][:state]
      end || [self, offset + 1].hash

      unless sym.nil?
        raise "Unreferenced rule #{sym.inspect}" if rule.nil?

        prec   = (rule.terminal? && rule.first.prec > 0) ? rule.first.prec : prec
        action = rule.nonterminal? ? :goto : :shift
        table[state][sym] = { :action => action, :state => new_state, :prec => prec }

        rule.build_parse_table(state, table, parser, seen) if action == :goto
        build_parse_table(new_state, table, parser, seen, new_offset, prec)
      else
        table[state][sym] = { :action => :reduce, :rule => self, :prec => prec }
      end

      resolve_conflicts(table[state], parser)
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
