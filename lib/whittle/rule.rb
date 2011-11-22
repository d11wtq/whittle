module Whittle
  class Rule
    NULL_ACTION = Proc.new { }
    LEX_ACTION  = Proc.new { |input| input }

    attr_reader :name
    attr_reader :action
    attr_reader :components

    def initialize(name, *components)
      @components = components
      @action     = NULL_ACTION
      @name       = name
      @terminal   = components.length == 1 && !components.first.kind_of?(Symbol)

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

    def build_parse_table(state, table, parser, seen, offset = 0)
      table[state] ||= {}
      sym        = components[offset]
      new_offset = offset + 1
      new_state  = if table[state].key?(sym)
        table[state][sym][:state]
      end || [self, offset + 1].hash

      unless sym.nil?
        if Symbol === sym && parser.rules[sym].nonterminal?
          table[state][sym] = { :action => :goto,  :state => new_state }
          parser.rules[sym].build_parse_table(state, table, parser, seen)
        else
          table[state][sym] = { :action => :shift, :state => new_state }
        end

        build_parse_table(new_state, table, parser, seen, new_offset)
      else
        table[state][sym] = { :action => :reduce, :rule => self }
      end
    end

    def as(&block)
      raise ArgumentError, "Rule#as requires a block, but none given" unless block_given?

      tap do
        @action = block
      end
    end

    def as_value
      as(&LEX_ACTION)
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
  end
end
