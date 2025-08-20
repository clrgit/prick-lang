module Prick::Lang
  # Error handlers
  #
  # Usage
  #   class SomeCompilerClass
  #     include ErrorFunctions
  #   end
  #
  module ErrorFunctions
    # :call-seq:
    #   error(message...)
    #   error(token, message...)
    #   error(lineno, charno, message...)
    #
    def error(*args)
      lineno, charno = parse_args!(args)
      $stderr.puts "#{file} #{lineno}:#{charno} #{args.join}"
      exit 1
    end

    def internal_error(*args)
      e = InternalError.new "INTERNAL ERROR: #{args.join}"
      e.set_backtrace caller_locations(1)
      raise pretty_backtrace!(e)
    end

    def self.pretty_backtrace!(e)
      e.set_backtrace(e.backtrace.map(&:to_s).grep_v /\/bundler?\b|\/ruby_executable_hooks:/)
      e
    end

    def pretty_backtrace!(e) ErrorFunctions.pretty_backtrace(e) end

  private
    def parse_args!(args) # Modifies 'args'
      case args.first
        when Integer; args.shift(2)
        when Token; [args.first.lineno, args.first.charno]
        else
          case self
            when Tokenizer; [self.lineno, self.charno]
          else
            raise "Internal internal error"
          end
      end
    end
  end
end
