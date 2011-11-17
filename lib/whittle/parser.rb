module Whittle
  class Parser
    class << self
      def rules
        @rules ||= {}
      end

      def rule(name)
        raise ArgumentError, "Parser.rule requires a block, but none was given" unless block_given?

        RuleSet.new.tap do |rule_set|
          rules[name] = rule_set
          yield rule_set
        end
      end

      def start(name = nil)
        @start = name unless name.nil?
        @start
      end
    end

    def rules
      self.class.rules
    end

    def parse(input)
      raise "Undefined start rule #{self.class.start}" unless rules.key?(self.class.start)

      rule      = rules[self.class.start]
      token     = nil
      lookahead = nil
      root      = {
        :name => self.class.start,
        :rule => nil,
        :args => []
      }
      stack = [root]

      require 'pp'

      lex(input) do |received|
        token     = lookahead
        lookahead = received
        next if token.nil?

        pp rule.table_for_offset(stack.last[:args].length)

        stack.last[:args] << token[:value]
        stack.last[:rule] = rules[token[:name]].first
      end

      reduce(stack.pop)
    end

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

      yield nil
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

    def reduce(tree)
      tree[:rule].action.call(*tree[:args].map { |arg| Hash === arg ? reduce(arg) : arg })
    end
  end
end
