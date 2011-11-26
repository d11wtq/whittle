module Whittle
  class RuleSet
    include Enumerable

    def initialize(name)
      @name  = name
      @rules = []
    end

    def each(&block)
      @rules.each(&block)
    end

    def [](*components)
      Rule.new(@name, *components).tap do |rule|
        @rules << rule
      end
    end

    def scan(source, line)
      each do |rule|
        if token = rule.scan(source, line)
          return token
        end
      end

      nil
    end

    def build_parse_table(table, parser, context)
      return table if context[:seen].include?([context[:state], self])

      context[:seen] << [context[:state], self]

      table.tap do
        each do |rule|
          rule.build_parse_table(table, parser, context)
        end
      end
    end

    def terminal?
      @rules.length == 1 && @rules.first.terminal?
    end

    def nonterminal?
      !terminal?
    end
  end
end
