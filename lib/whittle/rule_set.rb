module Whittle
  class RuleSet
    include Enumerable

    def initialize
      @rules = []
    end

    def each(&block)
      @rules.each(&block)
    end

    def [](*components)
      Rule.new(*components).tap do |rule|
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

    def table_for_offset(offset)
      @rules.inject([]) do |table, rule|
        table + rule.table_for_offset(offset)
      end
    end
  end
end
