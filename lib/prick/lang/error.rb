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
    #   error(object-w-token-method, message...)
    #   error(file, lineno, charno, message...) # file may be nil
    #
    def error(*args)
      file, lineno, charno = parse_args!(args)
      location = (lineno ? [file, "#{lineno}:#{charno}"].compact.join(" ") : file)
      msg = [location, args.join].compact.join(" ")
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

    def unexpected_error(arg = nil, expected, got)
      arg ||= (got.is_a?(Token) || got.respond_to?(:token) ? got : nil)
      klass = got.is_a?(Class) ? got : got.class
      expected = expected.respond_to?(:classname) ? expected.classname : expected.to_s
      error arg, "Expected #{expected}, got #{klass.classname}"
    end

  private
    def parse_args!(args) # Modifies 'args'
      args.shift if args.first.nil?
      case args.first
        when String
          if args[1] and args[1].is_a?(Integer)
            args.shift(3)
          else
            case self
              when Tokenizer; [self.file, self.lineno, self.charno]
              when Parser
                if k = self.tokenizer&.error_token
                  [k.file, k.lineno, k.charno]
                else
                  [curr.file, curr.lineno, curr.charno]
                end
            else
              [nil, nil, nil]
            end
          end
        when Integer;
          [nil] + args.shift(2)
        when Token
          t = args.shift
          [t.file, t.lineno, t.charno]
        else
          if args.first.respond_to?(:token)
            t = args.shift.token
            [t.file, t.lineno, t.charno]
          else
            [nil, nil, nil]
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
