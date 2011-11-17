module Whittle
  class Rule
    attr_reader :action
    attr_reader :components

    def initialize(*components)
      @components = components.map do |c|
        case c
          when String then Regexp.new("^#{Regexp.escape(c)}")
          when Regexp then Regexp.new("^#{c}")
          when Symbol then c
          else raise ArgumentError, "Unsupported rule component #{c.class}"
        end
      end

      @pattern = @components.first
      @lexable = (@components.count == 1 && Regexp === @pattern)
    end

    def as(&block)
      raise ArgumentError, "Rule#as requires a block, but none given" unless block_given?

      tap do
        @action = block
      end
    end

    def scan(source, line)
      return nil unless @lexable

      copy = source.dup
      if match = copy.slice!(@pattern)
        source.replace(copy)
        {
          :value     => match,
          :line      => line + ("~" + match + "~").lines.count - 1,
          :discarded => @action.nil?
        }
      end
    end

    def table_for_offset(offset)
      [{ :token => @components[offset], :lookahead => @components[offset + 1], :rule => self }]
    end
  end
end
