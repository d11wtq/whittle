module Whittle
  class Rule
    NULL_ACTION = Proc.new { }

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
      new_offset = offset + 1
      new_state  = [self, offset + 1].hash
      sym        = components[offset]

      unless sym.nil?
        if Symbol === sym && parser.rules[sym].nonterminal?
          parser.rules[sym].build_parse_table(state, table, parser, seen)

          # DEBUG (these rules need merging... and conflicts resolving)
          p "If match #{sym.inspect} then go #{state} => #{new_state}"
          if table[state].key?(sym)
            other_state = table[state][sym][:state]
            actions = table[other_state]
            p "State conflict for #{sym} when #{state}: existing actions are #{actions.inspect}"
          end
          # / DEBUG

          table[state].merge!( sym => { :action => :goto, :state => new_state } )
        else
          table[state].merge!( sym => { :action => :shift, :state => new_state } )
        end

        unless table.key?(new_state)
          table[new_state] ||= {}
          build_parse_table(new_state, table, parser, seen, new_offset)
        end
      else
        table[state].merge!( sym => { :action => :reduce, :rule => self } )
      end
    end

    def as(&block)
      raise ArgumentError, "Rule#as requires a block, but none given" unless block_given?

      tap do
        @action = block
      end
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
