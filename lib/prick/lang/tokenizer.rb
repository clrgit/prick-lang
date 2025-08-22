
module Prick::Lang
  class Tokenizer
    using String::Text

    include ErrorFunctions

    class TokenizerError < Prick::Lang::Error; end

    # Map from keyword or punctuation to token kind
    KEYWORDS = Token::TOKENS.compact.invert

    COMMENT_RE = /\s*(?:#.*)?/
    WORD_RE = /(\s*)(#{Token::WORD_RE})#{COMMENT_RE}/
    EXT_RE = /(?:sql|psql|rb|fox|prick)/
    FILENAME_RE = /^([\w-]+)\.(#{EXT_RE}\b)$/

    

#re = /\Ghej/
#
#line = "..hej"
#
#p re.match(line, 2)



    attr_reader :compiler

    # Source file
    forward_to :compiler, :file

    # Current line
    def line = @lines[@index]

    # Current line number (one-based)
    def lineno = @index + 1

    # Current character position (one-based)
    def charno = @pos + 1

    # Indent of current line
    def indent() = line && line[/\A */].size

    # Token of the last error
    attr_reader :error_token

    def initialize(compiler, lines = nil)
      constrain compiler, Compiler
      constrain lines, [String], nil
      @compiler = compiler
      @lines = lines || IO.readlines(file).map(&:rstrip)
      @index = 0 # Current line
      @pos = 0 # Current character
      @peek_token = nil # Current peek'ed token if present
    end

    # Return true if at end of file
    def eof?() @lines.size == @index end

    # Return true if at end of line. #eol? is also when at end of file
    def eol? = eof? || @pos == (line&.size || 0)

    # Return true if at beginning of line. #bol? is also true when at end of
    # file (FIXME)
    def bol? = eof? || @pos == 0

    # Set end of line
    def eol!() @pos = line&.size || 0 end

    # Return next token to be extracted. Return nil if at end of file
    def peek(kinds = nil)
      !eof && ensture_buffer or return nil
#     @buffer && !eol? and next_buffer or return nil
#     parse_token(kinds && Array(kinds))
    end


    # Extract and return next token. Advance to next line if this was the last
    # token on the line
    def read(kind = nil, peek: false)
      if peek && @peek_token
        p 1
        @peek_token
      elsif @peek_token
        p 2
        token = @peek_token
        @peek_token = nil
        kind.nil? || token.kind == kind or raise ArgumentError
        @pos += @peek_match_length
        next_line if eol?
        token
      else
        p 3
        p ">>> kind: #{kind.inspect}"
        case kind
          when :TEXT; return readtext(peek: peek)
          when :LINE; return readline(peek: peek)
          when :BLOCK; return readblock(peek: peek)
          else
            p 4
            if token = parse_token
              p 5
              if kind.nil? || kind == token.kind
                p 6
                puts ">>> peek: #{token.inspect}"
                puts ">>> peek: #{peek.inspect}"
                puts ">>> peek_match_length: #{@peek_match_length.inspect}"
                @pos += @peek_match_length if !peek
              else
                p 7
                @error_token = token
                return nil
              end
              next_line if !peek && eol?
            else
              p 8
              @error_token = readtext(peek: true)
              return nil
            end
        end
        if peek
          @peek_token = token
        else
          token
        end
      end
    end

    # Return the rest of the line as a TEXT token and advance to the next line.
    # Returns nil if at end of line
    def readtext(peek: false)
      !eof? && !eol? or return nil
      token = Token.new(file, lineno, charno, line[@pos..-1].lstrip, :TEXT)
      next_line if !peek
      token
    end

    # Return line as a (possibly empty) LINE token and advance to the next line. It is an error
    # if not at beginning of line
    def readline(peek: false)
      !eof? or return nil
      bol? or error "Not at start of line 1"
      token = Token.new(file, lineno, charno, line, :LINE)
      next_line if !peek
      token
    end

    # Return a BLOCK token of lines with indent bigger or equal to min_indent.
    # Lines with a '#' in the first column are replaced with an empty string
    # and then the block is aligned as a whole to the least indented line.
    # Leading and traling blank lines are ignored (but counted)
    def readblock(min_indent, peek: false) # exclusive min value
      !eof? or return nil
      bol? or error "Not at start of line" # Implies cached variables have been reset
      start_index = @index # Initial value of @index, no start_pos because #bol? is true

      skip_empty or return nil
      token_lineno = lineno # Line number of first non-blank line
      token_charno = charno # Position in first non-blank line

      block = []
      while !eof?
        if indent >= min_indent
          block << line
        elsif line == "" || line[0] == '#'
          block << ""
        else
          break
        end
        @index += 1
      end

      if block.empty?
        @index = start_index # Reset line
        return nil
      elsif peek
        @index = start_index # Reset line
      end

      Token.new(file, token_lineno, token_charno, block.join("\n").sub(/\n+\Z/, "").align, :BLOCK)
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
        puts "rest: #{line[@pos..-1].inspect}"
        puts "indent: #{@indent.inspect}"
        puts "pos: #{@pos.inspect}"
        puts "token: #{@peek_token.inspect}"
        if !@lines.empty?
          puts "lines:"
          indent { puts @lines&.map(&:inspect) }
        else
          puts "lines: []"
        end
      }
    end

# protected

    def reset_line
      @pos = 0
      @peek_token = nil
    end

    # Move to the next line. Returns nil
    def next_line
      @index += 1
      @pos = 0
      @peek_token = nil
    end

    # Read and ignore empty lines. Used by #readblock
    def skip_empty
      !eof? or return nil
      bol? or error "Not at start of line" # Implies cached variables have been reset
      while (norm = line&.sub(/^\s*/, ""))&.empty?
        @index += 1
      end
      norm
    end

#   # Skip trailing whitespace including comments
    # Read and ignore blank lines (incl. comments)
    def skip_blanks
      !eof? or return nil
      bol? or error "Not at start of line" # Implies line has been reset
      while (norm = line&.sub(COMMENT_RE, ""))&.empty?
        @index += 1
      end
      norm
    end

    def parse_token
      puts "#parse_token"
      Kernel.indent {
        puts "WORD_RE: #{WORD_RE}"
        puts "line: #{line.inspect}"
        puts "@pos: #{@pos}"
        puts "rest: #{line[@pos..-1].inspect}"
      }

      if m = WORD_RE.match(line, @pos)
        indent = m.match_length(1)
        word = m.match(2)
        wordcharno = m.offset(2).first + 1
        @peek_match_length = m.match_length(0) # Length of match including whitespace and comments

        if keyword_kind = KEYWORDS[word]
          Token.new(file, lineno, charno, word, keyword_kind)
        elsif File.basename(word) =~ FILENAME_RE
          filename, extname = $1, $2
          Token.new(file, lineno, charno, word, :FILE, filename, extname)
        else
          nil
        end
      else
        puts "NO MATCH"
        nil
      end
    end
  end
end

