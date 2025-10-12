
module Prick::Lang
  class Reader
    using String::Text

    attr_reader :file # Only used in error messages
    attr_reader :lines
    attr_reader :index
    attr_reader :pos

    def line = @lines[@index]
    def rest = @lines[@index]&.[](pos..-1)

    # Last read token
    attr_reader :token

    # Error token
    attr_reader :error

    def initialize(file, lines, reader = nil)
      @file = file
      @lines = lines
      if reader
        copy(reader)
      else
        @index = reader&.index || 0
        @pos = 0
      end
    end

    def copy(reader)
      @index = reader.index
      @pos = reader.pos
      @token = reader.token
      @error = reader.error
      self
    end

    # Return true if at end of file. Note that #eof? only reports on the current
    # position in the input before empty lines are scanned so it is possible to
    # have #eof? == false but get a EOF token from #read
    def eof? = @index >= @lines.size

    # Return true if at end of line. #eol? is also true when at end of file.
    # Note that #eol? only reports on the current position in the input before
    # blanks are scanned so it is possible to have #eol? == true but get a EOL
    # token from #read
    def eol? = @pos >= (@lines[@index]&.size || 0)

    # Return true if at beginning of line. #bol? is also true when at end of
    # file (FIXME)
    def bol? = eof? || @pos == 0

    # EOL and EOF are handled according to the :eol/:eof flags:
    #
    #   eol: true  - Return EOL token and advance reader
    #        false - Ignore EOL
    #   eof: true  - Return EOF token
    #        false - Return nil and set #error to EOF token
    #
    def read(eol: false, eof: false)
      @eol, @eof = eol, eof

      # Scan blank and comments
      scan(eol: eol) if !self.eof?
      return handle_eox(:EOF, eof) if self.eof?

      # Only happens if eol is true, otherwise the 'self.eof?' above would have triggered
      if self.eol?
        constrain eol, true
        return handle_eox(:EOL, eol)
      end

      # Match token. This will always match because of scan
      m = Token::TOKEN_RE.match(@lines[@index], @pos) or raise InternalError
      args = [file, @index + 1, m.begin(0) + 1, m.match(0)]
      @pos += m.match_length(0)
      @error = nil

      # Detect matched token type and extract value
      @token =
          if m[:keyword] || m[:punct] || m[:oper]
            Token.new *args, Token::TOKEN_KINDS[m.match(0)]
          elsif m[:file]
            FileToken.new(*args, m[:filepath], m[:file], m[:ext])
          elsif m[:dir]
            DirToken.new *args
          elsif m[:path]
            PathToken.new *args
          elsif m[:ident]
            Token.new *args, :IDENT
          elsif m[:ref]
            Token.new *args, :REF
          elsif m[:bool]
            Token.new *args, (m[:bool] == "true" ? :TRUE : :FALSE)
          elsif m[:ver]
            Token.new *args, :VER
          elsif m[:var]
            VarToken.new *args
          elsif m[:error]
            @error = ErrorToken.new *args
            nil
          else
            raise InternalError
          end
    end

    def dump
      puts "Reader"; indent {
        puts "index: #{index}"
        puts "pos: #{pos}"
#       puts "lines: #{lines.inspect}"
        puts "lines:"; indent {
          puts lines.map.with_index { |l, i| "[#{i}] #{l}" }.join("\n") #.align(empty: true)
        }
        puts "line: #{line.inspect}"
        puts "rest: #{rest.inspect}"
      }
    end

    def scan(eol: false, comment: false)
      re = comment ? Token::SCAN_BLANK_LINE_RE : Token::SCAN_COMMENT_LINE_RE

      # Match against rest-of-line. Stop at eol if not found
      @pos = re.match(@lines[@index], @pos)&.begin("text") || @lines[@index].size

      # Match against following lines
      if eol? && !eol
        @index += 1
        if offset = @lines[@index..-1].find_index { |l| @pos = re.match(l)&.begin("text") }
          @index += offset
        else
          @index = @lines.size
          @pos = 0
        end
      end
      self
    end

    # Handle eol and eof conditions. Advances the reader if emit is true
    def handle_eox(kind, emit)
      constrain kind, :EOF, :EOL
      token = Token.new(file, @index+1, @pos+1, nil, kind)
      if emit
        @token, @error = token, nil
        @index += 1 if !eof?
        @pos = 0
      else
        @token, @error = nil, token
      end
      @token
    end
  end
end

__END__

class Tokenizer
  attr_reader :reader
  attr_reader :peeker

  def initialize
    @reader = Reader.new(self)
    @peeker = Reader.new(self, @reader)
  end

  def peek(eol: false, eof: true)
    # peeker.read(flags)

  end

  def read(eol: false, eof: true)
#   if !@peeker.token

    if @peeker.token
      if @peeker.eol == eol && @peeker.eof = eof
        return @reader.copy(@peeker).token
      else
        @peeker.sync(reader)
      end
    end
    @peeker.read(eol: eol, eof: eof)
    @reader.copy(@peeker).token
  end
end








module Prick::Lang
  class Tokenizer
    # Tokenizer maintains a state for the current point in the file and a state
    # for the point after a token has been peek'ed. It could be modelled with a
    # reader object for the two states, that would also allow nested peeks, but
    # we don't to that because of the overhead in a critical spot in the code
    # (maybe)

    using String::Text
    include ErrorFunctions
    class TokenizerError < Prick::Lang::Error; end

    # Using (?<ws>) and (?<token>) because Ruby's unnamed captures acts
    # strangely if not all captures are named
    TOKEN_RE = /\G(?<ws>\s*)(?<token>#{Token::TOKEN_RE})#{Token::COMMENT_RE}/
    IDENT_RE = /\G(?<ws>\s*)(?<ident>#{Token::IDENT_RE})#{Token::COMMENT_RE}/

    # Source file
    attr_reader :file

    # Current line
    def line = @lines[@index]

    # Rest of current line
    def rest = @lines[@index]&.[](@pos..-1)

    # lineno/charno is the one-based position of the last token
    # index/pos is the position of the first character after the last token
    # peek_index/peek_pos is the position of the next token

    # Current line number (one-based). Note that @index may be one past the end
    # of the array, this is used to end the file with a eol and then a eof
    # token
    def lineno = @index + 1

    # Current character position (one-based)
    def charno = @pos + 1

    # Indent of current or given line
    def indent(l = line) = l && l[/\A */].size

    # Last read token. Note that this does not reflect the current state
    attr_reader :token

    # Token of the last read error
    attr_reader :error

    # Last peek'ed token
    attr_reader :peek_token

    # Token of the last peek'ed error
    attr_reader :peek_error

    def initialize(file, lines = nil)
      constrain file, String
      constrain lines, [String], nil
      @file = file
      @lines = (lines || IO.readlines(file)).map(&:rstrip).take_while { _1 !~ /^__END__$/ }
      trimlines

      # Current state
      @index = 0 # current line index
      @pos = 0 # current character index
      @token = nil
      @error = nil # last error token
      reset_peek
    end

    # Return true if at end of file
    def eof?(eol: false) = @index >= @lines.size + (eol ? 1 : 0)

    # Return true if at end of line. #eol? is also true when at end of file
    def eol? = eof?(eol: false) || @pos == line.size

    # Return true if at beginning of line. #bol? is also true when at end of
    # file (FIXME)
    def bol? = eof? || @pos == 0

    # True if we have a peek'ed token
    def peek? = !@peek_token.nil? || !@peek_error.nil?

#   # Return true if at end of file
#   def peek_eof?(eol: false) = @peek_index >= @peek_lines.size + (eol ? 1 : 0)
#
#   # Return true if at end of line. #eol? is also true when at end of file
#   def peek_eol? = peek_eof?(eol: false) || @peek_pos == peek_line.size

    # Return nil if no regular token was found but return EolToken/EofToken if
    # :eol/:eof is true and at the end of line/file. Scan through empty lines
    # if :eol is false
    #
    # Note that #peek has eof default true but #read has eof default false
    def peek(eol: false, eof: true)
      trace
      puts "#peek"
      indent { dump }
      return @peek_token if peek? && @peek_eol == eol && @peek_eof == eof

      reset_peek
      @peek_eol = eol
      @peek_eof = eof

#     if peek?
#       # Ignore peek'ed EOL or EOF token
#       if @peek_token&.kind == :EOL && !eol || @peek_token&.kind == :EOF && !eof
#         move
#       else
#         return @peek_token
#       end
#     end

      # scan to end of line
      #   if at end of line
      #     if use eol token
      #       return eol token
      #     else
      #       ignore it
      #     end
      #

      # Handle initial EOF
      if eof? #(eol: eol)
        puts ">> eof?"
        return @peek_token = handle_peek_eox(:EOF, eof)
      end


      # Handle initial EOL
      if eol?
        puts ">> eol?"
        # Move to next line
        @peek_index += 1
        @peek_pos = 0
#       dump
        return @peek_token = handle_peek_eox(:EOL, true) if eol
      end

      if eol
        # Scan current line
        puts "scan one"
        @peek_pos = scanline(@peek_index, @peek_pos)
        return handle_peek_eox(:EOL, eol) if @peek_pos >= @lines[@peek_index].size
      else
        # Scan blank lines
        puts "scan many"
        puts "  #{@peek_index}"
        puts "  #{@peek_pos}"
        @peek_index, @peek_pos = scanlines(@peek_index, @peek_pos)
        puts "  #{@peek_index}"
        puts "  #{@peek_pos}"

        # Handle after-scan EOF
        return handle_peek_eox(:EOF, eof) if @peek_index >= @lines.size

        puts "still here"
      end

      # Read token. Different token types are matched by different capture
      # groups
      puts "STRING: #{@lines[@peek_index][@peek_pos..-1].inspect}"
      puts "  peek_index: #{@peek_index}"
      m = TOKEN_RE.match(@lines[@peek_index], @peek_pos) or raise InternalError # Match always
      match = m.match(:token) # matching string
      match_charno = m.offset(:token).first + 1
      puts "  match: #{match.inspect}"
      puts "  match_charno: #{match_charno}"
      puts "  begin: #{m.begin(0)}"

#     @peek_pos += m.match_length(0)
      @peek_error = nil
      args = [file, @peek_index + 1, match_charno] # First three Token#new arguments

#     # Handle after-match EOL
#     if !eol && @peek_pos == @lines[@peek_index].size
#       @peek_index += 1
#       @peek_pos = 0
#     end

      # Detect matched token type and extract value
      @peek_token =
          if m[:keyword] || m[:punct] || m[:oper]
            Token.new *args, match, Token::TOKEN_KINDS[match]
          elsif m[:file]
            FileToken.new(*args, match, m[:path], m[:file], m[:ext])
          elsif m[:dir]
            DirToken.new *args, match
          elsif m[:path]
            PathToken.new *args, match
          elsif m[:ident]
            Token.new *args, match, :IDENT
          elsif m[:ref]
            Token.new *args, match, :REF
          elsif m[:bool]
            Token.new *args, match, (m[:bool] == "true" ? :TRUE : :FALSE)
          elsif m[:ver]
            Token.new *args, match, :VER
          elsif m[:var]
            VarToken.new *args, match
          elsif m[:error]
            @peek_error = ErrorToken.new *args, match
            nil
          else
            raise InternalError
          end
    end

    def with(eol: false, eof: false, &block)
      @default_eol = eol
      @default_eof = eof
      yield
    end

    # Return current peek'ed token and move to next token. Returns nil if peek?
    # is false and invalids the internal state so that would probably be an
    # error
    def move
      trace
      @index, @pos = @peek_index, @peek_pos
      @token, @error = @peek_token, @peek_error
      @peek_token = @peek_error = nil
      @peek_eol = @peek_eof = nil
      @token
    end

    def read(eol: false, eof: false)
      trace
      peek(eol: eol, eof: eof)
      move
#     puts "token: #{token.inspect}"
#     puts "peek_token: #{peek? ? peek_token.inspect : 'nil'}"
#     puts "peek? #{peek?}"
    end

    # Return the rest of the line as a LINE token and advance to the next line
    def readline(eol: false, eof: false)
      !eof? or return handle_eox(:EOF, eof)
      !eol? or return handle_eox(:EOL, eol)
      @error = nil
      @token = Token.new(file, lineno, charno, @lines[@index][@pos..-1].lstrip, :LINE)
      nextline # also updates peek_*
      @token
    end

    # Return a TEXT token of lines with indent bigger or equal to min_indent.
    # Lines with a '#' in the first column are replaced with an empty string
    # and then the block is aligned as a whole to the least indented line.
    # Leading and traling blank lines are ignored (but counted). Note that
    # #readtext will read the rest of the file if min_indent is 0
    def readtext(min_indent, eof: false)
      !eof? or return handle_eox(:EOF, eof)
      bol? or raise InternalError # We have to be at the beginning of line

      @error = nil
      error_index = @index # Index to use if not found
      @index, @pos = scanlines(@index, @pos, comment: true) # Ignore initial blank lines

      token_lineno = lineno # Line number of first non-blank line

      # Scan indented lines; column-one column lines are blanked-out. It
      # includes trailing blank lines that are removed later
      block = []
      non_blank_lines = []
      indents = []
      while !eof?
        if indent >= min_indent
          block << line
          non_blank_lines << line
          indents << indent
        elsif line == "" || line[0] == '#'
          block << ""
        else
          @pos = indent
          break
        end
        @index += 1
      end

      # Check if anything was found
      if non_blank_lines.empty?
        @error_token = eob_token(error_index)
        @index, @pos = error_index, 1 # Reset to position before error
        return @token = nil
      end

      # Set peek to current position
      reset_peek

      # Position in first non-blank line that is used to anchor the text token.
      # We can't use #charno because that is at the start of the line so we
      # access the indents array instead
      token_charno = indents[0] + 1

      # Format block as an aligned text string
      min = indents.min || 0
      source = block.map { |l| l[min..-1] }.join("\n").sub(/\n+\Z/, "") # #sub remove trailing blank lines

      Token.new(file, token_lineno, token_charno, source, :TEXT)
    end

    def readwords
      !eof? or return handle_eox(:EOF, false)
      !eol? or return handle_eox(:EOL, false)
      words = []
      while !eol? && m = Token::WORD_RE.match(@lines[@index], @pos)
        match = m.match(:word)
        match_charno = m.offset(:word).first + 1
        words << Token.new(file, lineno, match_charno, match, :WORD)
        @pos += m.match_length(0)
      end
      nextline
      words
    end

    def nextline
      @index += 1
      @pos = 0
      @error = nil
      reset_peek
    end

    def dump
      puts "Tokenizer"
      Kernel.indent {
        puts "file: #{file}"
        puts "eof?: #{eof?.inspect}"
        puts "bol?: #{bol?.inspect}"
        puts "eol?: #{eol?.inspect}"
        puts "index: #{@index.inspect}"
        puts "pos: #{@pos.inspect}"
        puts "line: #{@line.inspect}"
        puts "rest: #{line&.[](@pos..-1).inspect}"
        puts "indent: #{@indent.inspect}"
        puts "token: #{@token.inspect}"
        puts "error: #{@error.inspect}"
        puts "peek_index: #{@peek_index.inspect}"
        puts "peek_pos: #{@peek_pos.inspect}"
        puts "peek_token: #{@peek_token.inspect}"
        puts "peek_error: #{@peek_error.inspect}"
        puts "peek_eol: #{@peek_eol}"
        puts "peek_eof: #{@peek_eof}"
      }
    end

  protected
    def terminator_token(kind, lineo = self.lineno) = Token.new(file, lineno, 1, nil, kind)

    def eof_token(lineno = self.lineno) = Token.new(file, lineno, 1, nil, :EOF)
    def eol_token(lineno = self.lineno, charno = self.charno) = Token.new(file, lineno, charno, nil, :EOL)
    def eob_token(lineno = self.lineno, charno = self.charno) = Token.new(file, lineno, charno, nil, :EOB)

    def eof_error() @error_token = eof_token; @token = nil end
    def eol_error() @error_token = eol_token; @token = nil end

    def handle_eox(kind, flag)
      constrain kind, :EOF, :EOL
      token = Token.new(file, lineno, charno, nil, kind)
      @token, @error = *(flag ? [token, nil] : [nil, token])
      @token
    end

    # Handles an EOF/EOL condition. Return Eof/EolToken if :flag is true and
    # clear error state. Return nil if flag is false and set #error_token to
    # the Eof/EolToken. kind can be :EOF og :EOL
    def handle_peek_eox(kind, flag)
      constrain kind, :EOF, :EOL
      token = Token.new(file, lineno, charno, nil, kind)
      @peek_token, @peek_error = *(flag ? [token, nil] : [nil, token])
      @peek_token
    end

  public
    # made public as a hack. Problem is that #peek doesn't reset if flags changed
    def reset_peek
      @peek_index = @index
      @peek_pos = @pos
      @peek_token = nil # current peek'ed token if present
      @peek_error = nil # error token from last call to #peek
    end

  protected
    def scanline(index, pos, comment: false)
      puts "scanning #{@lines[index][pos..-1].inspect}"
      if m = /[^#\s]/.match(@lines[index], pos)
        puts "match at #{m.begin(0)}"
        return m.begin(0)
      else
        puts "no match"
        return @lines.size
      end
    end

#     m = TOKEN_RE.match(@lines[@peek_index], @peek_pos) or raise InternalError # Match always
#   end
#     m = TOKEN_RE.match(@lines[@peek_index], @peek_pos) or raise InternalError # Match always
#     match = m.match(:token) # matching string
#     match_charno = m.offset(:token).first + 1

    # Return index of first non blank line including the current line. Ignore
    # comment-only lines unless :comment is true. Returns lines.size on eof
    #
    # FIXME: Called A LOT!
    def scanlines(index, pos, comment: false)
#     trace index, pos, comment: comment
      re = (!comment ? Token::COMMENT_LINE_RE : Token::BLANK_LINE_RE)
      offset = @lines[index..-1].find_index { |l| !re.match(l) }
      index = (offset ? index + offset : @lines.size)
      pos = 0 if (offset || 1) > 0
      [index, pos]
    end

    # Removes trailing blank or comment-only lines
    def trimlines
      while @lines.last && @lines.last =~ Token::COMMENT_LINE_RE
        @lines.pop
      end
    end
  end
end



