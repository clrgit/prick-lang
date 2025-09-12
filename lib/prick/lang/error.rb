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
    #   error(ast-node, message...)
    #   error(lineno, charno, message...)
    #
    def error(*args)
      lineno, charno = parse_args!(args)
      msg = "#{file} #{lineno}:#{charno} #{args.join}"
      if defined?(::RSpec) || USE_EXCEPTION
        pretty_error Error, msg
      else
        $stderr.puts msg
        exit 1
      end
    end

    def internal_error(*args)
      pretty_error InternalError, "INTERNAL ERROR: #{args.join}"
    end

  private
    def parse_args!(args) # Modifies 'args'
      case args.first
        when Integer; args.shift(2)
        when Token; t = args.shift; [t.lineno, t.charno]
        when Ast::Node; n = args.shift.token; [n.lineno, n.charno]
        else
          case self
            when Tokenizer; [self.lineno, self.charno]
            when Parser
              if k = self.tokenizer&.error_token
                [k.lineno, k.charno]
              else
                [curr.lineno, curr.charno]
              end
          else
            raise ArgumentError
          end
      end
    end

    def pretty_error(klass, msg)
      e = klass.new msg
      e.set_backtrace caller_locations(2).map(&:to_s)
      raise pretty_backtrace!(e)
    end

    def self.pretty_backtrace!(e)
      e.set_backtrace(e.backtrace.map(&:to_s).grep_v /\/bundler?\b|\/ruby_executable_hooks:/)
      e
    end

    def pretty_backtrace!(e) ErrorFunctions.pretty_backtrace!(e) end
  end
end
