
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

    attr_reader :compiler

    # Source file
    forward_to :compiler, :file

    # Current line
    def line = @lines[@index]

    # Current line number (one-based)
    def lineno = @index + 1

    # Current character position (one-based)
    def charno = @pos + 1

    # Indent of current or given line
    def indent(l = line) = l && l[/\A */].size

    # Token of the last read error
    attr_reader :error

    # Token of the last peek'ed error
    attr_reader :peek_error

    def initialize(compiler, lines = nil)
      constrain compiler, Compiler
      constrain lines, [String], nil
      @compiler = compiler
      @lines = lines || IO.readlines(file).map(&:rstrip)

      # Current state
      @index = 0 # current line index
      @pos = 0 # current character index
      @token = nil
      @error = nil # last error token

      # Peek state
      @peek_index = 0
      @peek_pos = 0
      @peek_token = nil # current peek'ed token if present
      @peek_error = nil # error token from last call to #peek
    end

    # Return true if at end of file
    def eof? = @lines.size == @index

    # Return true if at end of line. #eol? is also when at end of file
    def eol? = eof? || @pos == line.size

    # Return true if at beginning of line. #bol? is also true when at end of
    # file (FIXME)
    def bol? = eof? || @pos == 0

    # True if we have a peek'ed token. Note that error token is not considered
    def peek? = !@peek_token.nil? #&& !@peek_error.nil?

#   # Indent of peek'ed line
#   def peek_indent(l = @lines[@peek_index]) = l && l[/\A */].size

    # Return EolToken at end of line if :eol is true
    def peek(eol: false)
#     puts "#peek(eol: #{eol})"
#     puts "  index, peek_index: #{@index}, #{@peek_index}"
#     puts "  @lines: #{@lines.inspect}"

      return @peek_token if peek?

      # Handle initial EOF state
      if eof?
        return eof_token

      # Handle eol initial EOL state
      elsif eol?
        if eol # return EolToken
          @error_token = nil
          return @peek_token = eol_token(@peek_index, @peek_pos)
        end

        # Ignore EOL
        @peek_index += 1
        @peek_pos = 0

        # Scan blank lines
        @peek_index = scanlines(@peek_index)

        # Handle after-scan EOF state
        if @peek_index == @lines.size
          @error_token = nil
          return @peek_token = eof_token(@peek_index+1)
        end
      end

      # Read token
      m = TOKEN_RE.match(@lines[@peek_index], @peek_pos) # Match always
      match = m.match(:token) # matching string
      match_charno = m.offset(:token).first + 1
      @peek_pos += m.match_length(0)
      @peek_error = nil
      args = [file, @peek_index + 1, match_charno] # First three Token#new arguments

      @peek_token =
          if capture = m[:word]
            Token.new *args, match, Token::WORDS[match] #Token::WORDS[capture]
          elsif m[:dir]
            DirToken.new *args, match
          elsif m[:file]
            FileToken.new(*args, match, m[:path], m[:file], m[:ext])
          elsif m[:int]
            Token.new(*args, match, :INT)
          elsif m[:ident]
            Token.new(*args, match, :IDENT)
          elsif m[:ref]
            Token.new(*args, match, :REF)
          elsif capture = m[:error]
            @peek_error = CharErrorToken.new(*args, capture)
            nil
          else
            raise InternalError
          end
    end

    def read
      peek
      @index = @peek_index
      @pos = @peek_pos
      @token = @peek_token; @peek_token = nil
      @error = @peek_error; @peek_error = nil
      @token
    end

    # Return the rest of the line as a LINE token and advance to the next line.
    # Returns nil if at end of line
    def readline(eol: false)
      !eof? or return eof_error
      !eol? or return eol_error
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
    def readtext(min_indent)
      !eof? or return eof_error
      !eol? or return eol_error
      bol? or raise InternalError

      @error = nil

      error_index = @index # Index to use if not found
      @index = scanlines(@index, comment: true) # Ignore initial blank lines

      token_lineno = lineno # Line number of first non-blank line

      # Scan indented lines and blank-out column-one comment lines. Also
      # compute minimal text indent
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

    def nextline
      @index += 1
      @pos = 0
      reset_peek
    end

    def dump
      puts "Tokenizer"
      Kernel.indent {
        puts "file: #{compiler.file}"
        puts "eof?: #{eof?.inspect}"
        puts "bol?: #{bol?.inspect}"
        puts "eol?: #{eol?.inspect}"
        puts "index: #{@index.inspect}"
        puts "pos: #{@pos.inspect}"
        puts "line: #{line.inspect}"
        puts "rest: #{line&.[](@pos..-1)&.inspect}"
        puts "indent: #{@indent.inspect}"
#       puts "token: #{@peek_token.inspect}"
#       if !@lines.empty?
#         puts "lines:"
#         Kernel.indent { puts @lines.map(&:inspect) }
#       else
#         puts "lines: []"
#       end
      }
    end

  protected
    def eof_token(lineno = self.lineno) = Token.new(file, lineno, 1, nil, :EOF)
    def eol_token(lineno = self.lineno, charno = self.charno) = Token.new(file, lineno, charno, nil, :EOL)
    def eob_token(lineno = self.lineno, charno = self.charno) = Token.new(file, lineno, charno, nil, :EOB)

    def eof_error() @error_token = eof_token; @token = nil end
    def eol_error() @error_token = eol_token; @token = nil end

    def reset_peek
      @peek_index = @index
      @peek_pos = @pos
      @peek_token = nil
      @peek_error = nil
    end

    # Return index of first non blank line including the current line.  Ignore
    # comment-only lines unless :comment is false.  Returns lines.size on eof
    def scanlines(index = @index, comment: false)
      re = (comment ? Token::COMMENT_LINE_RE : Token::BLANK_LINE_RE)

      offset = @lines[index..-1].find_index { |l| !re.match(l) }
#     puts "scanlines:"
#     puts "  match: #{re.match("eval").inspect}"
#     puts "  @lines[index..-1]: #{@lines[index..-1].inspect}"
#     puts "  offset: #{offset.inspect}"
      (offset ? index + offset : @lines.size)
    end
  end
end









__END__









        # Handle eof? after skipping blank lines
        if peek_eof?
          @peek_token = eof_token
        else # Find token
        if token = parse_token
          if kind.nil? || kind == token.kind # Expected
            true
          elsif kind == :IDENT && token.keyword? # Fix keyword/identifier ambiguity
            token.kind = :IDENT
          else # Token mismatch
            @error = TokenErrorToken.new(token)
            return nil
          end
          @pos += @peek_match_length if !peek
          nextline if !peek && eol?
        else
          return nil
        end

        # Set peek_token
        (peek and @peek_token = token) || token

        end

        # Check kind and raise if mismatch
        kind.nil? || kind == @peek_token.kind or
            raise InternalError, "#read/#peek mismatch: #{kind}/#{token.kind}"
        return @peek_token


          @error = EofToken.new
          @error = TokenErrorToken.new(eof_token)
          return nil
        end
        @error = nil

        # Handle text tokens
        case kind
          when :LINE; return readline(peek: peek)
          when :TEXT; return readtext(peek: peek)
        end

        # Parse token. Set error and return nil if an error is found
        if token = parse_token
          if kind.nil? || kind == token.kind # Expected
            true
          elsif kind == :IDENT && token.keyword? # Fix keyword/identifier ambiguity
            token.kind = :IDENT
          else # Token mismatch
            @error = TokenErrorToken.new(token)
            return nil
          end
          @pos += @peek_match_length if !peek
          nextline if !peek && eol?
        else
          return nil
        end

        # Set peek_token
        (peek and @peek_token = token) || token
      end
    end

#   def peek end
#   def peekline end
#   def peektext end





    # Skips the peek'ed token. Raises if no peek'ed token
    def skip
      @peek_token or raise InternalError
      read
    end

    # Return next or current token. Return nil if at end of file
#   def peek(kind = nil) = read kind, peek: true

    # Return index of first non blank line including the current line.  Ignore
    # comment-only lines unless :comment is false.  Returns lines.size on eof
    def scanlines(comment: true)
      re = (comment ? Token::COMMENT_RE : /^\s*/)
      offset = lines[index..-1].find_index { |l| !re.match(l) }
      offset ? index + offset : @lines.size
    end

    # Raise if kind is different from the peek'ed kind
    def peek2(kind = nil)
      if @peek_token.nil?
        # Scan blank lines. Don't ignore comment-only lines if kind is TEXT
        @peek_index = scanlines(comment: kind != :TEXT)

        # Handle eof? after skipping blank lines
        if peek_eof?
          @peek_token = eof_token
        else # Find token
        if token = parse_token
          if kind.nil? || kind == token.kind # Expected
            true
          elsif kind == :IDENT && token.keyword? # Fix keyword/identifier ambiguity
            token.kind = :IDENT
          else # Token mismatch
            @error = TokenErrorToken.new(token)
            return nil
          end
          @pos += @peek_match_length if !peek
          nextline if !peek && eol?
        else
          return nil
        end

        # Set peek_token
        (peek and @peek_token = token) || token

        end

        # Check kind and raise if mismatch
        kind.nil? || kind == @peek_token.kind or
            raise InternalError, "#read/#peek mismatch: #{kind}/#{token.kind}"
        return @peek_token


          @error = EofToken.new
          @error = TokenErrorToken.new(eof_token)
          return nil
        end
        @error = nil

        # Handle text tokens
        case kind
          when :LINE; return readline(peek: peek)
          when :TEXT; return readtext(peek: peek)
        end

        # Parse token. Set error and return nil if an error is found
        if token = parse_token
          if kind.nil? || kind == token.kind # Expected
            true
          elsif kind == :IDENT && token.keyword? # Fix keyword/identifier ambiguity
            token.kind = :IDENT
          else # Token mismatch
            @error = TokenErrorToken.new(token)
            return nil
          end
          @pos += @peek_match_length if !peek
          nextline if !peek && eol?
        else
          return nil
        end

        # Set peek_token
        (peek and @peek_token = token) || token
      end
    end

    # Extract and return next token or EOL or EOF if at end of line or file.
    # Returns nil and sets #error if unsuccesful
    #
    #
    # Advance to next line if this was the last token on the line.
    #
    def read(kind = nil, peek: false)
#     puts "#read"
#     Kernel.indent {
#       puts "line: #{line.inspect}"
#       puts "rest: #{line[@pos..-1].inspect}"
#       puts "eof?: #{eof?}"
#       puts "bol?: #{bol?}"
#       puts "eol?: #{eol?}"
#     }

      if peek && @peek_token # Return peek'ed token if peeking
        @peek_token
      elsif @peek_token # Consume peek'ed token if present
        token = @peek_token
        @peek_token = @error = nil
        kind.nil? || token.kind == kind or error "#read/#peek mismatch: #{kind}/#{token.kind}"
        @pos += @peek_match_length
        nextline if eol?
        token
      else # Compute new token
        # Skip blank lines if not expecting a block token
        skiplines if bol? && kind != :TEXT

        # Handle eof? after skipping blank lines
        if eof?
          @error = TokenErrorToken.new(eof_token)
          return nil
        end
        @error = nil

        # Handle text tokens
        case kind
          when :LINE; return readline(peek: peek)
          when :TEXT; return readtext(peek: peek)
        end

        # Parse token. Set error and return nil if an error is found
        if token = parse_token
          if kind.nil? || kind == token.kind # Expected
            true
          elsif kind == :IDENT && token.keyword? # Fix keyword/identifier ambiguity
            token.kind = :IDENT
          else # Token mismatch
            @error = TokenErrorToken.new(token)
            return nil
          end
          @pos += @peek_match_length if !peek
          nextline if !peek && eol?
        else
          return nil
        end

        # Set peek_token
        (peek and @peek_token = token) || token
      end
    end

    # Return the rest of the line as a LINE token and advance to the next line.
    # Returns nil if at end of line
    def readline(peek: false)
      !eof? && !eol? or return nil
      token = Token.new(file, lineno, charno, line[@pos..-1].lstrip, :LINE)
      nextline if !peek
      token
    end

    # Return a TEXT token of lines with indent bigger or equal to min_indent.
    # Lines with a '#' in the first column are replaced with an empty string
    # and then the block is aligned as a whole to the least indented line.
    # Leading and traling blank lines are ignored (but counted). Note that
    # #readtext will read the rest of the file if min_indent is 0
    def readtext(min_indent, peek: false) # exclusive min value
#     puts "#readtext"

      !eof? or return nil
      bol? or error "Not at start of line" # Implies cached variables have been reset
      start_index = @index # Initial value of @index, no start_pos because #bol? is true

      skiplines(comment: false) # Ignore initial blank lines
      token_lineno = lineno # Line number of first non-blank line
      token_charno = charno # Position in first non-blank line

      # Scan indented lines and blank-out column-one comment lines
      block = []
      non_blank_lines = []
      while !eof?
        if indent >= min_indent
          block << line
          non_blank_lines << line
        elsif line == "" || line[0] == '#'
          block << ""
        else
          break
        end
        @index += 1
      end

      # Check if anything was found
      if non_blank_lines.size == 0
#       @index = start_index # Reset line
#       return nil
        Token.new(file, token_lineno, token_charno, "", :TEXT)
      end

      # Find least indented line (ignoring blanks) and outdent block to that
      # level
      level = non_blank_lines.map { indent _1 }.min
      block.map! { |l| l[level..-1] || "" }

      # Reset line if peeking
      @index = start_index if peek

      # Format block as an aligned text string
      min = block.reject(&:empty?).map { |l| indent(l) }.min
      source = block.map { |l| l[min..-1] }.join("\n").sub(/\n+\Z/, "") # #sub remove trailing bland lines

      Token.new(file, token_lineno, token_charno, source, :TEXT)
    end

    # Skip blank lines and also comment-only lines unless :comment is false.
    # Returns nil on eof
    def skiplines(comment: true)
      re = (comment ? Token::COMMENT_RE : /^\s*/)
      while line&.sub(re, "")&.empty?
        @index += 1
      end
      @lines[@index]
    end

    def dump
      puts "Tokenizer"
      Kernel.indent {
        puts "file: #{compiler.file}"
        puts "eof?: #{eof?.inspect}"
        puts "bol?: #{bol?.inspect}"
        puts "eol?: #{eol?.inspect}"
        puts "index: #{@index.inspect}"
        puts "line: #{line.inspect}"
        puts "rest: #{line&.[](@pos..-1)&.inspect}"
        puts "indent: #{@indent.inspect}"
        puts "pos: #{@pos.inspect}"
        puts "token: #{@peek_token.inspect}"
        if !@lines.empty?
          puts "lines:"
          Kernel.indent { puts @lines.map(&:inspect) }
        else
          puts "lines: []"
        end
      }
    end

  protected
    # Move to the next line. Returns nil
    def nextline
      @index += 1
      @pos = 0
      @peek_token = nil
    end

    def eof_token
      Token.new file, lineno, 1, "", :EOF
    end

    # Return keyword/punctuation, dir, file, ident, reference, or text token.
    # Return nil if no match was found
    #
    # Expects line to be non-empty and not comment-only so TOKEN_RE will always
    # match
    def parse_token
#     puts "#parse_token"
#     Kernel.indent {
#       puts "eof?: #{eof?}"
#       puts "line: #{line.inspect}"
#     }
      m = TOKEN_RE.match(line, @pos) # Match always
      indent = m.match_length(:ws) # leading whitespace
      match = m.match(:token) # matching string
      match_charno = m.offset(:token).first + 1
      @peek_match_length = m.match_length(0) # Length of match including whitespace and comments
      @error = nil

      if c = m[:word]
        Token.new file, lineno, match_charno, match, Token::WORDS[c]
      elsif m[:dir]
        DirToken.new file, lineno, match_charno, match
      elsif m[:file]
        FileToken.new(file, lineno, match_charno, match, m[:path], m[:file], m[:ext])
      elsif m[:int]
        Token.new(file, lineno, match_charno, match, :INT)
      elsif m[:ident]
        Token.new(file, lineno, match_charno, match, :IDENT)
      elsif m[:ref]
        Token.new(file, lineno, match_charno, match, :REF)
      elsif c = m[:error]
        @error = CharErrorToken.new(file, lineno, match_charno, c)
        nil
      else
        raise InternalError
      end
    end

  end
end

