module Whittle
  class Parser
    class << self
      def rules
        @rules ||= {}
      end

      def rule(name)
        raise ArgumentError, "Parser.rule requires a block, but none was given" unless block_given?

        RuleSet.new(name).tap do |rule_set|
          rules[name] = rule_set
          yield rule_set
        end
      end

      def start(name)
        rule(:*) do |r|
          r[name].as { |prog| prog }
        end
      end

      def initial_state
        [rules[:*], 0].hash
      end

      def parse_table
        rules[:*].build_parse_table(initial_state, {}, self)
      end
    end

    def rules
      self.class.rules
    end

    def parse(input)
      raise "Undefined start rule" unless rules.key?(:*)

      table  = self.class.parse_table
      states = [self.class.initial_state]
      args   = []

      require 'pp'
      #pp table

      lex(input) do |token|
        input = token

        catch(:match) do
          loop do
            state = table[states.last]

            if instruction = (state[input[:name]] || state[input[:value]] || state[nil])
              case instruction[:action]
                when :shift
                  input[:args] = [input.delete(:value)]
                  states << instruction[:state]
                  args   << input
                  throw :match
                when :reduce
                  sym    = {
                    :rule => instruction[:rule],
                    :name => instruction[:rule].name,
                    :line => 0,
                    :args => args.pop(instruction[:rule].components.length)
                  }
                  sym[:line] = sym[:args].first[:line]
                  states.pop(instruction[:rule].components.length)
                  args << sym
                  input = sym
                  # FIXME: I don't believe this is the correct place for this
                  throw :match if states.length == 1 && token[:name] == :$eof
                when :goto
                  input = token
                  states << instruction[:state]
              end
            else
              #pp args
              pp states
              parse_error(state, input)
            end
          end
        end
      end

      reduce(args.pop)
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

      yield ({ :name => :$eof, :line => line, :value => nil })
    end

    def parse_error(state, input)
      message = <<-ERROR.gsub(/\n\s+/, " ").strip
      Parse error:
      expected
      #{state.keys.map { |k| k.inspect }.join("; or ")}
      but got
      #{input[:name].inspect}
      on line
      #{input[:line]}
      ERROR

      raise message
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
