
module Prick::Lang
  class Tokenizer
    using String::Text
    include ErrorFunctions
    class TokenizerError < Prick::Lang::Error; end

    # Using (?<ws>) and (?<token>) because Ruby's unnamed captures acts
    # strangely if not all captures are named
#   LINE_RE = /\G(?<ws>\s*)(?<token>#{Token::TOKEN_RE})#{Token::COMMENT_RE}/
    LINE_RE = /\G(?<ws>\s*)(?<token>#{Token::TOKEN_RE})#{Token::COMMENT_RE}/

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

    # Return next or current token. Return nil if at end of file
    def peek(kind = nil) = read kind, peek: true

    # Extract and return next token. Advance to next line if this was the last
    # token on the line. Returns nil and sets error token if unsuccesful
    def read(kind = nil, peek: false)
      if peek && @peek_token # Return peek'ed token if peeking
        @peek_token
      elsif @peek_token # Consume peek'ed token if present
        token = @peek_token
        @peek_token = nil
        kind.nil? || token.kind == kind or error "#read/#peek mismatch: #{kind}/#{token.kind}"
        @pos += @peek_match_length
        nextline if eol?
        token
      else # Compute new token
        skiplines if bol?
        case kind
          when :TEXT; return readtext(peek: peek)
          when :LINE; return readline(peek: peek)
          when :BLOCK; return readblock(peek: peek)
          when :IDENT; return readident(peek: peek) # FIXME remove?
          when :FILE; # Why?
          else # keyword or file
            if token = parse_token
              if kind.nil? || kind == token.kind
                @pos += @peek_match_length if !peek
              else
                @error_token = TokenErrorToken.new(token)
                return nil
              end
              nextline if !peek && eol?
            else
              return nil
            end
        end
        (peek and @peek_token = token) || token
      end
    end

    # Return the rest of the line as a TEXT token and advance to the next line.
    # Returns nil if at end of line
    def readtext(peek: false)
      !eof? && !eol? or return nil
      token = Token.new(file, lineno, charno, line[@pos..-1].lstrip, :TEXT)
      nextline if !peek
      token
    end

    # Return current line as a LINE token and advance to the next line. Note
    # that the line can be empty. It is an error if not at beginning of line
    def readline(peek: false)
      skiplines if bol?
      !eof? or return nil
      bol? or error "Not at start of line 1"
      token = Token.new(file, lineno, charno, line, :LINE)
      nextline if !peek
      token
    end

    # Return a BLOCK token of lines with indent bigger or equal to min_indent.
    # Lines with a '#' in the first column are replaced with an empty string
    # and then the block is aligned as a whole to the least indented line.
    # Leading and traling blank lines are ignored (but counted). Note that
    # setting min_indent to 0 will cause #readblock to read the rest of the
    # file
    def readblock(min_indent, peek: false) # exclusive min value
      !eof? or return nil
      bol? or error "Not at start of line" # Implies cached variables have been reset
      start_index = @index # Initial value of @index, no start_pos because #bol? is true

      skiplines(comment: false) # Ignore initial blank lines
      token_lineno = lineno # Line number of first non-blank line
      token_charno = charno # Position in first non-blank line

      # Scan indented lines and blank-out initial comments
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

    # Skip blank lines and also comment-only lines unless :comment is false
    def skiplines(comment: true)
      !eof? or return nil
      bol? or error "Not at start of line" # Implies line has been reset
      re = (comment ? Token::COMMENT_RE : /^\s*/)
      while line&.sub(re, "")&.empty?
        @index += 1
      end
    end

    # Return keyword/punctuation, dir, file, ident, reference, or text token.
    # Return nil if no match was found
    #
    # Expects line to be non-empty and not comment-only so LINE_RE will always
    # match
    def parse_token
      m = LINE_RE.match(line, @pos) # Match always
      indent = m.match_length(:ws) # leading whitespace
      match = m.match(:token) # matching string
      match_charno = m.offset(:token).first + 1
      @peek_match_length = m.match_length(0) # Length of match including whitespace and comments

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
        Token.new(file, lineno, match_charno, match, :REEF)
      else
        c = m[:error] or raise Error # Should never happen
        @error_token = ErrorToken.new(file, lineno, match_charno, c, :ERROR)
        nil
      end
    end
  end
end

__END__
    def make_rule
    end

    # Tokens are interpreted in this order
    #   * Tokens with a string literal
    #   * ident

    # [:SCHEMA, :IDENT, :TEXT]
    # [:TEXT, :BLOCK]
    def expect(*kinds)
      kinds = kinds.flatten
      !eof? or return (kind.include? :EOF ? EofToken.new : nil)
      !eol? or return (kind.include? :EOL ? EolToken.new : nil)

      if token = peek




      return read if kinds.include? token.kind

      regular_kinds = [0...kinds.find_index {

      return nil if !kinds.include? token


      match_kinds = []

      kind = kinds.shift

      if kind == :KEYWORD
        eat_other_keywords
        return success


      while kind = kinds.shift
        case Tuple::TOKEN_KINDS[kind] ||
          when :KEYWORD;
          when :MATCH;
          when :TERMINATOR; # never happens
          when :TEXT
            case kind

      while Tuple::KEYWORD_TOKENS.key? kinds.first
        kinds.shift
      if Tuple::KEYWORD_TOKENS.key? kind

        w




      while

      re = []

      kinds.each { |kind|
        keywords << kind if kind
        if RE.key?
        RE[kind]




      kinds.each { |kind|
        return
          case kind
            when :TEXT; readtext(peek: peek)
            when :LINE; readline(peek: peek)
            when :BLOCK; readblock(peek: peek)


            when :IDENT; readident(peek: peek)

            when :FILE;
            else # keyword or file
              if token = parse_token
                if kind.nil? || kind == token.kind
                  @pos += @peek_match_length if !peek
                else
                  @error_token = token
                  nil
                end
                nextline if !peek && eol?
              else
                @error_token = readtext(peek: true)
                nil
              end

          end
      }

    end

