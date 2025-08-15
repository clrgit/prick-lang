
module Prick::Lang
  class Tokenizer
    attr_reader :compiler
    attr_reader :tokens

    forward_to :compiler, :file
    attr_reader :lineno
    attr_reader :charno
    attr_reader :level
    attr_reader :word

    # A tokenizer starts reading the file immediately but should only be
    # instantiated within the Compiler#compile method that is going to read the
    # file anyway
    def initialize(compiler)
      @compiler = compiler
      @lines = IO.readlines(file).map { |line|
        line.sub(/#.*/, "").sub(/\s*$/, "")
      }

      @lineno = 0
      @charno = nil
      @level = nil
      @whitespace = nil
      @word = nil
    end

    def eof?() @lineno >= @lines.size end
    def eol?() @charno >= (line&.size || 0) end

    def line = @lines[@lineno - 1]
    def rest = line&.[](@charno - 1 .. -1)

    # Read line into buffer
    def readline
      @lineno += 1
      @charno = 1

      # Skip blank lines
      while @lineno <= @lines.size && line =~ /^$/
        @lineno += 1
      end

      return nil if @lineno > @lines.size
      return nil if line == "__END__"

      # Update word and level
      update
      @level = @whitespace
      line
    end

    def peekword
      if eol?
        readline or return nil
        word
      else
        word
      end
    end

    # Extract next word, prefixed whitespace is ignored
    def readword
      puts "readword"
      readline if lineno == 0
      return nil if eof?
      if eol?
        puts "  eol?"
        readline or return nil
        w = word
        skipchars(@whitespace + @word.size)
      else
        puts "  !eol?"
        w = word
        skipchars(@whitespace + @word.size)
      end
      p w
      w
    end

    # Extract 'n' chars. It is assumed that the line has already been read
    # using #readline
    def readchars(n)
      chars = rest[@charno - 1, n]
      @charno += n
      if eol?
        readline
      else
        update
      end
      chars
    end

    def skipchars(n)
      @charno += n
      if eol?
        readline
      else
        update
      end
    end

    # Get next token
    def get()
#     readword
#     case word
#       when 'hej'; puts "Hej"
#       when 
    end

    # Get a TEXT token of the rest of the line
    def gettext()
    end

    def dump
      puts "Tokenizer(#{file})"
      indent {
        puts "lines : #{@lines.size}"
        puts "lineno: #{lineno}"
        puts "charno: #{charno}"
        puts "level : #{level}"
        puts "word  : #{word}"
        puts "spaces: #{@whitespace}"
        puts "eol?  : #{eol?}"
        puts "eof?  : #{eof?}"

      }
    end

  protected
    def update
      m = /(\s*)(\{|\}|\w+|.*)/.match(line, @charno-1)
      @whitespace = m.match_length(1)
      @word = m[2]
    end
  end
end

__END__



    def eof?() end

    def skipchars(n)
      @charno += n
      update
    end

    def skiplines
      while @lineno <= @lines.size && @lines[@lineno -1] =~ /^$/
        @lineno += 1
        @charno = 1
      end
      # TODO check for eof
      update
    end

    def readchars(n)
      chars = rest[0...n]
      skipchars(n)
      chars
    end

    def readline()
      @lineno < @lines.size or return nil
      @lineno += 1
      @charno = 1
      update
      @level = @whitespace
      @line
    end

    def readword()
      word = self.word
      skipchars(@whitespace + word.size)
      update
      word
    end

    def getchars(n)
      ensure_line or return nil
      from = @charno - 1
      @charno += n
      chars = @line[from...@charno]
      @line[@charno - 1, -1] =~ /^(\s*)(\{|\}|\w+)/
      @level = $1.size

    end

    def getword
      ensure_line or return nil
      getchars(word.size)
    end

    def getword
      word = self.word
      getchars(word.size)

    end

    def get
      if kind = Token::WORDS[word]
        Token.new(file, lineno, charno, kind, getword)

        word = getchars(word.size)

        kind = Token::WORDS[word] || :TEXT

        case word
          when '{'; :BLOCK_BEGIN
          when '}'; :BLOCK_END
        else
          if Token::KEYWORDS.include? word
            word.upcase.to_sym
          else
            return Token.new(file, lineno, charno, :TEXT, getchars(@line.size - @charno + 1))
          end
        end

      getchars(word)
    end

    # Return the rest of the line as a TEXT token
    def gettext
      ensure_line or return nil
      Token.new(file, lineno, charno, :TEXT, getchars(@line.size - @charno + 1))
    end



    KINDS = %w(SCHEMA OPTIONS IF CASE INIT TERM META SEEDS AUTH EXEC EVAL RUBY FILE EXPR)

        when '{'; :BLOCK_BEGIN
        when '}'; :BLOCK_END
    end


    def ensure_line
      if @line.nil?
        !eof? or return nil
        @line = @file.gets(chomp: true)
        @lineno += 1
        @charno = 1
        @line =~ /^\s*/
        @level = $&.size
        @pos = 0
        @peek = nil
      end
      @line
    end

    # Only non-empty when at start of string
    def peek_level()
      @level or begin
        ensure_line
        @level
      end

    def peek_word()
      ensure_line
    peek; return @peek_word end

    # Return an [level, word] tuple
    def peek()
      @peek ||= begin
        ensure_line or return nil
        /^(\s*)(\{|\}|\w+)/ =~ @line[pos..]
        [$1.size, $2]
      end
    end

    def get()


      @buffer or peek
      r = peek or return nil
      @peek = nil
      getnext()
      r
    end

    @buffer ||= peeend
    def getline(kind: 'EXPR') end
    def unget(token) end

  private
    def make_token
    end

    def advance
      r = @buffer
    end

    def readline
    end


    def readchar()
      @current = @file.getc
    end

    def skip_ws
      while @file.
    end
  end
end
