
module Prick::Lang
  class Reader
    using String::Text

    attr_reader :path # Path relative to the user's current directory
    attr_reader :lines
    attr_reader :index
    attr_reader :pos

    def line = @lines[@index]
    def rest = @lines[@index]&.[](pos..-1)

    # Last read token
    attr_reader :token

    # Error token
    attr_reader :error

    def initialize(path, lines, reader = nil)
      @path = path
      @lines = lines
      if reader
        copy(reader)
      else
        @index = reader&.index || 0
        @pos = 0
      end
    end

    # True if a token has been read. This is only true before the first call to
    # #read and after #reset
    def read? = !(@token || @error).nil?

    # Reset read status of reader. Used when the reader is a peeker
    def reset() @token = @error = nil end

    def copy(other)
      @index = other.index
      @pos = other.pos
      @token = other.token
      @error = other.error
      self
    end

    def sync(other)
      @index, @pos = other.index, other.pos
      @token = @error = nil
    end


    # Return true if at end of path. Note that #eof? only reports on the current
    # position in the input before empty lines are scanned so it is possible to
    # have #eof? == false but get a EOF token from #read
    def eof? = @index >= @lines.size

    # Return true if at end of line. #eol? is also true when at end of path.
    # Note that #eol? only reports on the current position in the input before
    # blanks are scanned so it is possible to have #eol? == true but get a EOL
    # token from #read
    def eol? = @pos >= (@lines[@index]&.size || 0)

    # Return true if at beginning of line. #bol? is also true when at end of
    # path (FIXME)
    def bol? = eof? || @pos == 0

    # Return next token
    #
    # EOL and EOF are handled according to the :eol/:eof flags:
    #
    #   eol: true  - Return EOL token and advance reader
    #        false - Ignore EOL
    #   eof: true  - Return EOF token
    #        false - Return nil and set #error to EOF token
    #
    def read(eol: false, eof: false)
#     @eol, @eof = eol, eof

      # Scan blank and comments
      scan(eol: eol) if !self.eof?
      return handle_eox(:EOF, eof) if self.eof?

      # Only happens if eol is true, otherwise the 'self.eof?' above would have triggered
      return handle_eox(:EOL, eol) if self.eol?

      # Reset error
      @error = nil

      # Match token. This will always match because of scan
      m = Token::TOKEN_RE.match(@lines[@index], @pos) or raise InternalError
      args = [path, @index + 1, m.begin(0) + 1, m.match(0)]
      @pos += m.match_length(0)

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

    # Return the rest of the line as a LINE token
    def readline(eol: false, eof: false)
      !eof? or return handle_eox(:EOF, eof)
      !eol? or return handle_eox(:EOL, eol)
      @error = nil
      @token = Token.new(path, @index+1, @pos+1, @lines[@index][@pos..-1].lstrip, :LINE)
      @pos = @lines[@index].size
      @token
    end

    # Return a TEXT token of lines with indent bigger than :limit. The block
    # is aligned as a whole to the least indented line, except that lines with
    # a '#' in the first column are replaced with an empty string. Leading and
    # traling blank lines are ignored
    def readtext(limit, eob: false, eof: false)
      trace
      !eof? or return handle_eox(:EOF, eof)

      # Scan to first non blank and remember position
      scan(comment: true)
      token_charno = @pos + 1
      token_lineno = @index + 1

      # Collect lines
      block = []
      found = false
      while !eof? && ((is_comment = @lines[@index][0] == '#') || @pos > limit)
        # Add line
        if is_comment
          block << ""
        else
          block << @lines[@index][limit..-1]
          found = true
        end

        # Advance to next line and scan
        @index += 1
        @pos = 0
        break if eof?
        scan(eol: true, comment: true)
      end

      # Check if anything was found
      if !found
        return handle_eox(:EOF, eof) if eof?
        return handle_eox(:EOB, eob)
      end

      # Find minimal indent (in excess of limit)
      min_indent = block.map(&:indentation).select { _1 > 0 }.min || 0

      # Format block as an aligned text string. '.sub(...)' removes trailing
      # blank lines
      source = block.map { |l| l[min_indent..-1] }.join("\n").sub(/\n+\Z/, "")

      # Create token using position of first non-blank character
      @error = nil
      @token = Token.new(path, token_lineno, token_charno, source, :TEXT)
    end

    # Read a EOL token. Returns false
    def readeol(eof: false)
      !eof? or return handle_eox(:EOF, eof)
      token = read(eol: true)
      @token, @error = nil, @token if token.kind != :EOL
      return @token
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
      constrain kind, :EOF, :EOL, :EOB
      token = Token.new(path, @index+1, @pos+1, nil, kind)
      if emit
        @token, @error = token, nil
        @index += 1 if !eof? && kind != :EOB
        @pos = 0
      else
        @token, @error = nil, token
      end
      @token
    end
  end
end







