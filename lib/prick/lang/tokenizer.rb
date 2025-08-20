

module Prick::Lang
  class Tokenizer
    include ErrorFunctions

    class TokenizerError < Prick::Lang::Error; end

    attr_reader :compiler

    # Source file
    forward_to :compiler, :file

    # Current line number (one-based)
    def lineno = @index + 1

    # Current character position (one-based)
    def charno = @pos + 1

    # Indent of current line
#   def indent() @indent ||= @lines[@index][/\A */].size end

    def initialize(compiler)
      @compiler = compiler
      @lines = IO.readlines(file).map(&:chomp)
      @index = 0 # Current line
      @indent = nil # Indent level of current line
      @pos = 0 # Current character
      @token = nil # Current peek'ed token if present
    end

    # Return next token to be extracted. Return nil if at end of file
    def peek(kinds = nil)
      !eof && ensture_buffer or return nil

#     @buffer && !eol? and next_buffer or return nil
#     parse_token(kinds && Array(kinds))
    end

    # Extract and return next token
    def read(kind = nil)
      peek(kind) or return nil
      extract_token
    end

    # Return the rest of the line as a TEXT token. Returns nil if at end of
    # line
    def readtext()
#     puts "#readtext"
#     puts "  index: #{@index}"
#     puts "  pos: #{@pos}"
#     puts "  eof?: #{eof?}"
#     puts "  eol?: #{eol?}"
      !eof? or return nil
      !eol? or return nil
      token = Token.new(file, lineno, charno, @lines[@index][@pos..-1].lstrip, :TEXT)
      token
    end

    # Extract and return next line as a LINE token. It is an error if any text
    # remains on the current line
    def readline()
      !eof? or return nil
      !b? || bob? or error "Not at start of line"
      token = Token.new(file, lineno, charno, @lines[@index], :LINE)
      eol!
      reset_line
      next_line
      token
    end

# protected

    # Return true if at end of file
    def eof?() @lines.size == @index end

    # Return true if at end of line. #eol? is also true when eof? or if the
    # buffer has not been loaded yet
    def eol? = eof? || @pos == (@lines[@index]&.size || 0)

    def eol!() @pos = @lines[@index]&.size || 0 end

    def reset_line
      @indent = nil
      @pos = 0
      @token = nil
    end

    # NOTE: Does not reset line; it is the caller's responsibility
    def next_line = eof? ? nil : @lines[@index+=1]

    def find_line 
      puts "#find_line"
      puts "  line: #{@lines[@index].inspect}"
      puts "  index: #{@index}"
      puts "  pos: #{@pos}"
      puts "  eof?: #{eof?}"
      puts "  eol?: #{eol?}"
      !eof? or return nil
      eol? or error "Not at end of line"
      reset_line
      while (line = next_line&.sub(/^\s*(?:#.*)$/, ""))&.empty? ; end
      line
    end
  end
end

__END__

#   # True if buffer has been loaded
#   def b? = !@buffer.nil?
#
#   # End of buffer
#   def eob? = @pos == @buffer&.size
#
#   # Set end of buffer
#   def eob!() @pos = (@buffer ||= @lines[@index]).size end
#
#   # Start of buffer
#   def bob? = !b? || @pos == 0
#
#   def ensure_buffer
#     b? && !eob? or load_buffer
#   end

#   def load_buffer
#     reset_buffer
#     while (@buffer = next_line&.sub(/^\s*(?:#.*)$/, ""))&.empty? ; end
#     @buffer
#   end
#
#   def next_buffer
#     reset_buffer
#     while (@buffer = next_line&.sub(/^\s*(?:#.*)$/, ""))&.empty? ; end
#     @buffer
#   end

    #############################################

    def load_line
#     reset_buffer
      impl_load_line
    end

    def impl_load_line
      return nil if eof?
#     @lines.size == @index ? nil : @lines[@index+=1]
      @lines[@index+=1]
    end

    # Parse a token. The buffer is cleared if at the end of line after the token
    # has been extracted
    def parse_token(kind = nil)
    end

    def extract_token
    end
  end
end

__END__





module Prick::Lang
  class Tokenizer
    # Map from keyword or punctuation to token kind
    KEYWORDS = Token::TOKENS.compact.invert

    PEEK_RE = /((\s*)(#{Token::WORD_RE}))/
    EXT_RE = /(?:sql|psql|rb|fox|prick)/
    FILENAME_RE = /^([\w-]+)\.(#{EXT_RE}\b)$/

    attr_reader :compiler
    forward_to :compiler, :file

    attr_reader :line, :lineno, :charno

    def initialize(compiler)
      @compiler = compiler
      @lines = IO.readlines(file).map { |line| line.sub(/#.*/, "").sub(/\s*$/, "") }
      @buffer = nil
      @lineno = 0 # Index in @lines of next line
      @charno = 0 # Index in @buffer of next character
      peekreset
    end

    def eol?() @buffer.nil? || @buffer.size == @charno end
    def eof?() @lines.size == @lineno && eol? end
    def peek?() !@peektoken.nil? end # Token has been cached
    def empty?() @lines.empty? end

    # Line indent. Zero-based, nil if line is empty
    def indent()
      peekword if !peek?
      @peekindent
    end

    def peekreset()
      @peekindent = @peekcharno = @peeklength = @peekword = @peektoken = nil
    end

    # Peek word
    def peekword(rest: false)
      @peekword ||= begin
        readline(rest: rest) if eol?
        if m = PEEK_RE.match(@buffer, @charno-1)
          @peekindent ||= m.match_length(2)
          @peekcharno = m.offset(3).first + 1
          @peeklength = (rest ? @buffer.size - @peekindent : m.match_length(3))
          @buffer[@peekcharno-1, @peeklength]
        else # Empty line, should only happen when called through #peekline
          @peekindent = nil
          @peekcharno = 0
          @peeklength = 0
          ""
        end
      end
    end

    # Peek rest of line excluding leading whitespace
    def peektext()
      peekword(rest: true) if !peek?
      @buffer[@peekcharno-1..-1]
    end

    # Peek full line. Do not skip empty lines
    def peekline()
      eol? or raise ArgumentError, "Not at end of line"
      peekword(rest: true)
    end

    # Index of peek word
    def peekcharno()
      peekword if !peek?
      @peekcharno
    end

    # Return the next token to be read. The kind argument explicitly sets the
    # token kind; this is used to get a TEXT token that eats up the rest of the
    # line
    def peektoken(kind = nil)
      return nil if eof?
      if @peektoken.nil?
        readline if eol?

        # detect kind and build array of [text, kind, filename=nil, extname=nil]
        # arguments to Token#initialize
        if kind == :TEXT
          args = [peektext, :TEXT]
        elsif kind == :LINE
          eol? or raise ArgumentError, "Not at start of line"
          args = [@buffer, :LINE]
        elsif kind
          args = [peekword, kind]
        elsif kind = KEYWORDS[peekword]
          args = [peekword, kind]
        elsif File.basename(peekword) =~ FILENAME_RE
          filename, extname = $1, $2
          args = [peekword, :FILE, filename, extname]
        else
          args = [peektext, :TEXT]
        end
        @peektoken = Token.new(file, lineno, peekcharno, *args)
      else
        kind.nil? || @peektoken.kind == kind or raise ArgumentError "token kind mismatch"
      end
    end

    # Ignore peek'ed token. As a safeguard, it is an error if the token hasn't
    # been peek'ed
    def skiptoken(kind = nil)
      peek? or raise ArgumentError "can't skip unknown token"
      readtoken(kind)
    end

    # Read and return the next token. It is an internal error if kind is
    # different from the cached token's kind if both are present
    def readtoken(kind = nil)
      return nil if eof?
      kind.nil? || !peek? || peektoken.kind == kind or raise ArgumentError "read/peek mismatch"
      token = peektoken(kind)
      @charno = @charno + @peeklength
      peekreset
      token
    end

    # Read and return next line. Blank lines are excluded (but counted) unless :rest is true
    def readline(rest: false)
      while @buffer = @lines[@lineno]
        @lineno += 1
        break if rest || !@buffer.empty?
      end
      @charno = 1
      peekreset
      return @buffer
    end
  end
end

