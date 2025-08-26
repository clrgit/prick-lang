
module Prick::Lang
  class Tokenizer
    using String::Text
    include ErrorFunctions
    class TokenizerError < Prick::Lang::Error; end

    # Using (?<ws>) and (?<token>) because Ruby's unnamed captures acts
    # strangely if not all captures are named
#   TOKEN_RE = /\G(?<ws>\s*)(?<token>#{Token::TOKEN_RE})#{Token::COMMENT_RE}/
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
    def eof?()
#     skiplines if @pos == 0 # Scan through empty lines
      @lines.size == @index
    end

    # Return true if at end of line. #eol? is also when at end of file
#   def eol? = eof? || @pos == (line&.size || 0)
    def eol? = eof? || @pos == line.size

    # Return true if at beginning of line. #bol? is also true when at end of
    # file (FIXME)
    def bol? = eof? || @pos == 0

    # Return next or current token. Return nil if at end of file
    def peek(kind = nil) = read kind, peek: true

    # Skips the peek'ed token. Raises if no peek'ed token
    def skip
      @peek_token or raise InternalError
      read
    end

    # Extract and return next token. Advance to next line if this was the last
    # token on the line. Returns nil and sets error token if unsuccesful
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
        @peek_token = @error_token = nil
        kind.nil? || token.kind == kind or error "#read/#peek mismatch: #{kind}/#{token.kind}"
        @pos += @peek_match_length
        nextline if eol?
        token
      else # Compute new token
        # Skip blank lines if not expecting a block token
        skiplines if bol? && kind != :BLOCK

        # Handle eof? after skipping blank lines
        if eof?
          @error_token = TokenErrorToken.new(eof_token)
          return nil
        end
        @error_token = nil

        # Handle text tokens
        case kind
          when :TEXT; return readtext(peek: peek)
          when :LINE; return readline(peek: peek)
          when :BLOCK; return readblock(peek: peek)
        end

        # Parse token. Set error_token and return nil if an error is found
        if token = parse_token
          if kind.nil? || kind == token.kind # Expected
            true
          elsif kind == :IDENT && token.keyword? # Fix keyword/identifier ambiguity
            token.kind = :IDENT
          else # Token mismatch
            @error_token = TokenErrorToken.new(token)
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
    # #readblock will read the rest of the file if min_indent is 0
    def readblock(min_indent, peek: false) # exclusive min value
#     puts "#readblock"

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
        @index = start_index # Reset line
        return nil
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

      Token.new(file, token_lineno, token_charno, source, :BLOCK)
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
      re = (comment ? Token::COMMENT_RE : /^\s*/)
      while line&.sub(re, "")&.empty?
        @index += 1
      end
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
      @error_token = nil

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
        @error_token = CharErrorToken.new(file, lineno, match_charno, c)
        nil
      else
        raise InternalError
      end
    end
  end
end

__END__
    # [:IDENT, :SCHEMA] <- not legal
    # [
    # [:SCHEMA, :IDENT, :TEXT]
    # [:TEXT, :BLOCK]
#   def expect(*kinds)
#     kinds = kinds.flatten
#     !eof? or return (kind.include? :EOF ? EofToken.new : nil)
#     !eol? or return (kind.include? :EOL ? EolToken.new : nil)
#
#     if token = peek
#       return read if kinds.include? token.kind
#       if kinds.include? :IDENT && token.keyword?
#         token.kind = :IDENT
#         return read
#       end
#     else
#       if kinds.include? :TEXT && !eol?
#         return readtext
#       elsif kinds.include? :LINE && !eof?
#         return readline
#       elsif kinds.include? :BLOCK
#         return readblock
#       end
#     end
#   end

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

