
module Prick::Lang
  class Compiler
    include ErrorFunctions

    attr_reader :file
    attr_reader :tokenizer
    attr_reader :parser
    attr_reader :oracle
    attr_reader :analyzer

    attr_reader :ast # Ast::Program
    attr_reader :idr # Idr::Program

    def initialize(file, lines = nil)
      @file = file
      @tokenizer = Tokenizer.new(file, lines)
      @parser = Parser.new(@tokenizer)
      @oracle = Oracle.new # TODO
      @analyzer = Analyzer.new(self, oracle)
    end

    def ftime(time, limit: "ms")
      units = %w(s ms μs ns)
      for unit in units
        if time < 1
          if unit == limit
            time = time.round(3)
            break
          end
          time *= 1000
        else
          if time > 100
            time = time.round(0)
          elsif time > 10
            time = time.round(1)
          else
            time = time.round(2)
          end
          break
        end
      end
      return time.to_s + unit
    end

    def time(title, &block)
      t0 = Time.now
      r = yield
      t1 = Time.now
      puts "#{title} (#{ftime t1 - t0})"
      r
    end

    def compile
      time "Parsing #{file}" do
        @ast = @parser.parse
      end

      time "Analyzing" do
        @idr = @analyzer.analyze
      end

#     puts "Dumping"
#     program.dump
    end
  end
end
