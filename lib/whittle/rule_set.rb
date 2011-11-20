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

    def build_parse_table(state, table, parser, seen = [])
      return table if seen.include?([state, self])

      seen << [state, self]

      table.tap do
        each do |rule|
          rule.build_parse_table(state, table, parser, seen)
        end
      end
    end

    # expr: (, expr, )
    # expr: expr, +, expr
    # expr: expr, *, expr
    # expr: num

    def terminal?
      @rules.length == 1 && @rules.first.terminal?
    end

    def nonterminal?
      !terminal?
    end
  end
end
