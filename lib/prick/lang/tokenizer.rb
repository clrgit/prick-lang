
module Prick::Lang
  class Tokenizer
    using String::Text
    include ErrorFunctions
    class TokenizerError < Prick::Lang::Error; end

    # Source file
    attr_reader :file

    # Reader object
    attr_reader :reader

    # Peeker object
    attr_reader :peeker

    def initialize(file, lines = nil)
      constrain file, String
      constrain lines, [String], nil
      @file = file
      @lines = (lines || IO.readlines(file)).map(&:rstrip).take_while { _1 !~ /^__END__$/ }
#     trimlines
      @reader = Reader.new(@file, @lines)
      @peeker = Reader.new(@file, @lines)
    end

    forward_to :@reader, :line, :rest, :token, :error, :eof?, :eol?
    def peek_token = @peeker.token
    def peek_error = @peeker.error

    # Return nil if no regular token was found but return EolToken/EofToken if
    # :eol/:eof is true and at the end of line/file. Scan through empty lines
    # if :eol is false
    #
    # Note that #peek has eof default true but #read has eof default false
    def peek(eol: false, eof: true)
      # Return peek'ed token if present and with the same set of flags
      return @peeker.token if @peeker.read? && @peek_eol == eol && @peek_eof == eof

      # Store flags and reset peeker
      @peek_eol = eol
      @peek_eof = eof
      @peeker.sync(@reader)
      return @peeker.read(eol: eol, eof: eof)
    end

    def read(eol: false, eof: false)
      if @peeker.read?
        if @peek_eol == eol && @peek_eof == eof
          @reader, @peeker = [@peeker, @reader]
        else
          @reader.read(eol: eol, eof: eof)
        end
        @peeker.reset
      else
        @reader.read(eol: eol, eof: eof)
      end
      @reader.token
    end

    def readline(eol: false, eof: false)
      @peeker.reset
      @reader.readline(eol: eol, eof: eof)
    end

    def readtext(limit, eob: false, eof: false)
      @peeker.reset
      @reader.readtext(limit, eob: eob, eof: eof)
    end

    def readeol(eof: false)
      @peeker.reset
      @reader.readeol(eof: eof)
    end
  end
end

