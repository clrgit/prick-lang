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
      @line = nil
      @lineno = 0 # Index in @lines of next line
      @charno = 0 # Index in @line of next character
      peekreset
    end

    def eol?() @line.nil? || @line.size == @charno end
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
        if m = PEEK_RE.match(@line, @charno-1)
          @peekindent ||= m.match_length(2)
          @peekcharno = m.offset(3).first + 1
          @peeklength = (rest ? @line.size - @peekindent : m.match_length(3))
          @line[@peekcharno-1, @peeklength]
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
      @line[@peekcharno-1..-1]
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
          args = [@line, :LINE]
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
      while @line = @lines[@lineno]
        @lineno += 1
        break if rest || !@line.empty?
      end
      @charno = 1
      peekreset
      return @line
    end
  end
end

