
module Prick::Lang
  class Tokenizer < CompilerProcess
    using String::Text
    class TokenizerError < Prick::Lang::Error; end

    # Source file as referred to in the source (eg. ./t.prick)
    attr_reader :file

    # Relative path to source file. Used from parser to add paths to file
    # objects
    attr_reader :dir

    # Path to file relative to the current directory of the user running the
    # program
    attr_reader :path

    # Reader object
    attr_reader :reader

    # Peeker object
    attr_reader :peeker

    def initialize(file, lines = nil)
      constrain file, String
      constrain lines, [String], nil
      @file = file
      @path = compiler.userpath(file)
      @dir = File.dirname(@path)
      @lines = (lines || IO.readlines(file)).map(&:rstrip).take_while { _1 !~ /^__END__$/ }
      @reader = Reader.new(@path, @lines)
      @peeker = Reader.new(@path, @lines)
    end

    forward_to :@reader, :line, :rest, :token, :error, :eof?, :eol?
    def peek_token = @peeker.token
    def peek_error = @peeker.error

    # Return nil if no token was found in the rest of the line/file but return
    # EolToken/EofToken if :eol/:eof is true and at the end of line/file. Scan
    # through empty lines if :eol is false
    def peek(eol: false, eof: false)
      # Return peeked token if present and with compatible flags
      return @peeker.token if peek?(eol: eol, eof: eof)

      # Store flags and reset peeker
      @peek_eol = eol
      @peek_eof = eof
      @peeker.sync(@reader)
      return @peeker.read(eol: eol, eof: eof)
    end

    # Return true if peek is valid and is compatible with the given flags
    def peek?(eol: false, eof: false)
      @peeker.read? &&
        (@peek_eol == eol || !eol && @peeker.token.kind != :EOL) &&
        (@peek_eof == eof || !@peeker.eof?)
    end

    def read(eol: false, eof: false)
      # Use peek'ed token if present and if flags are identical to current
      if @peeker.read?
        if peek?(eol: eol, eof: eof)
          @reader, @peeker = [@peeker, @reader]
        else
          @reader.read(eol: eol, eof: eof)
        end
        @peeker.invalidate!
      else
        @reader.read(eol: eol, eof: eof)
      end
      @reader.token
    end

    def readpath(eol: false, eof: false)
      @peeker.invalidate!
      @reader.readpath(eol: eol, eof: eof)
    end

    def readline(eol: false, eof: false)
      @peeker.invalidate!
      @reader.readline(eol: eol, eof: eof)
    end

    def readtext(limit, eob: false, eof: false)
      @peeker.invalidate!
      @reader.readtext(limit, eob: eob, eof: eof)
    end

    def readeol(eof: false)
      @peeker.invalidate!
      @reader.readeol(eof: eof)
    end

    def dump
      puts "Tokenizer"; indent {
        puts "peek_eol: #{@peek_eol}"
        puts "peek_eof: #{@peek_eof}"
        if peek?
          peeker.dump("Peeker")
        else
          puts "Peeker: invalid"
        end
        reader.dump
      }
    end
  end
end

