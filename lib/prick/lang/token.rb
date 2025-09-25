
module Prick::Lang
  class Token
    # Tokens
    TOKENS = {
      # Top level keywords
      PROGRAM: nil,
      SCHEMA: "schema",
      OPTION: "option",
      REQUIRE: "require",
      PROVIDE: "provide",
      FUNCTION: "function",
      RETURN: "return",

      # Phases
      INIT: "init",
      TERM: "term",
      META: "meta",
      SEEDS: "seed",
      AUTH: "auth",

      # Control structures
      IF: "if",
      ELSE: "else",
      ELSIF: "elsif",
      END: "end",
      CASE: "case",
      WHEN: "when",
      FROM: "from",

      # Commands
      EXEC: "exec",
      EVAL: "eval",
      RUBY: "ruby",
      SQL: "sql",
      CALL: "call",

      # Query operators (in addition to 'schema')
      ENV: "env",
      CMD: "cmd",
      USER: "user",
      VAR: "var",
      OBJECT: "object",
      RESOURCE: "resource",
      VERSION: "version", # Version keyword, see also :VER

      # Punctuation
      BRACE_BEGIN: "{",
      BRACE_END: "}",

      # Operators
      PAREN_BEGIN: "(",
      PAREN_END: ")",
      ANDAND: "&&",
      OROR: "||",
      LE: "<=", # Order is important because this matches against prefixes
      LT: "<",
      EQEQ: "==",
      EQ: "=",
      NE: "!=",
      GE: ">=",
      GT: ">",
      TIGT: "~>", # 'TI' for tilde
      EXCLAIM: "!",
      PIPE: "|",

      # Identifiers
      IDENT: nil,
      REF: nil,

      # Literals
      FILE: nil,
      DIR: nil,
      VER: nil, # Version number, see also :VERSION

      # Text literals
      LINE: nil, # Line of text
      TEXT: nil, # Multiple lines

      # Terminators. They are positioned one-beyond the end of line/block/file
      EOL: nil,
      EOB: nil, # End-of-block
      EOF: nil,

      # Error
      ERROR: nil
    }

    # Maps from keyword/punctuation-character to kind. Inverse map of TOKENS
    TOKEN_KINDS = TOKENS.select { _2.is_a? String }.invert

    # Texts for error messages: Token strings are enclosed in quotes, other
    # tokens are defined below
    TEXTS = TOKEN_KINDS.transform_values { "'#{_1}'" }.merge({
      IDENT: "identifier",
      REF: "reference",
      FILE: "file",
      DIR: "directory",
      VAR: "variable",
      VER: "version number",
      WORD: "file",
      LINE: "text",
      TEXT: "indented text",
      EOL: "EOL",
      EOB: "EOB",
      EOF: "EOF"
    })

    # List of all token kinds
    KINDS = TOKENS.keys

    # List of phase kinds
    PHASES = [:INIT, :TERM, :META, :SEED, :AUTH]

    # List of identifier kinds
    IDENTS = [:IDENT] + PHASES

    REFS = [:IDENT, :REF]

#   TOKEN_KIND_KINDS = TOKENS.select { _2 }.keys
#   KEYWORD_KINDS = TOKENS.select { _2.to_s =~ /^\w+$/ }.keys
#   PUNCT_KINDS = TOKEN_KIND_KINDS - KEYWORD_KINDS
#
#   TOKEN_RES =
#     KEYWORDS_KINDS.map { |kind| [kind, KEYWORD_RE] } +
#     PUNCT

    # List of keywords
    KEYWORDS = TOKEN_KINDS.keys.select { _1.to_s =~ /^\w+$/ }

    # List of punctuation characters (strings are allowed by not used)
    PUNCTS = TOKEN_KINDS.keys - KEYWORDS

    # List of recognized file types. They are reserved keywords and can't be used
    # for function or resources
    EXTS = %w(sql psql rb fox prick)

    # *_PATTERN regular expressions do not generate captures
    KEYWORD_PATTERN = /\b#{Regexp.union KEYWORDS}\b/
    PUNCT_PATTERN =  /#{Regexp.union PUNCTS}/
    FILE_PATTERN = /[^\/\s\0*?"`'$<>|:\[\]]+/ # Any legal linux filename
    EXT_PATTERN = Regexp.union(EXTS) # recognized file extensions
    RELDIR_PATTERN = /\.{1,2}\/|\// # initial '/', '../', or './'
    DIR_PATTERN = /#{RELDIR_PATTERN}?(?:#{FILE_PATTERN}\/)+/ # path ending in '/'
    IDENT_PATTERN = /[_a-zA-Z]\w*/ # language identifier
    REF_PATTERN = /#{IDENT_PATTERN}?\.#{IDENT_PATTERN}/
    VER_PATTERN = /\d+(?:\.(\d+)(?:\.(\d+))?)?/

    # *_RE regular expressions generate captures
    KEYWORD_RE = /(?<keyword>#{KEYWORD_PATTERN})/
    PUNCT_RE = /(?<punct>#{PUNCT_PATTERN})/
    FILE_RE = /(?<path>#{DIR_PATTERN})?(?<file>#{FILE_PATTERN}\.(?<ext>#{EXT_PATTERN}))/
    DIR_RE = /(?<dir>#{DIR_PATTERN})/
    REF_RE = /(?<ref>#{REF_PATTERN})/
    IDENT_RE = /(?<ident>#{IDENT_PATTERN})/
    VER_RE = /(?<version>#{VER_PATTERN})/

    # TODO
#   IDENT_REF_RE = /(?<ref>(?<ident>#{IDENT_PATTERN})?(?:\.#{IDENT_PATTERN})+)/

    ERROR_RE = /(?<error>\S*)/

    # Matches line endings, ignoring comments. Only used by the tokenizer
    COMMENT_RE = /\s*(?:#.*)?/

    BLANK_LINE_RE = /^\s*$/
    COMMENT_LINE_RE = /^#{COMMENT_RE}$/

    # TOKEN_RE matches words (keywords and punctuation), directories, files,
    # integer, identifiers, and references in that order; text and terminator
    # tokens are not matched. Sets $1 to the initial whitespace and $2 to the
    # non-blank part of the match. The kind of the token can be inferred from
    # the named captures: word, dir, path, file, ext, int, ident, ref
    TOKEN_RE =
        /#{KEYWORD_RE}|#{PUNCT_RE}|#{DIR_RE}|#{FILE_RE}|#{REF_RE}|#{IDENT_RE}|#{VER_RE}|#{ERROR_RE}/

    WORD_RE = /\s*(?<word>\S+)/

#   TOKEN_RES =
#     KEYWORDS.map { |k|

    # Matches as far as possible in the string. This is the same as TOKEN_RE
    # except filesystem names that matches nearly everything. Note that while
    # ERROR_RE (included in TOKEN_RE) matches the whole failing string,
    # ERROR_TOKEN_RE is used to pin-point the character that made TOKEN_RE to
    # fail
    ERROR_TOKEN_RE = /^(?:#{REF_PATTERN}|#{VER_PATTERN}|#{IDENT_PATTERN})(?<char>.)/

    attr_reader :file
    attr_reader :lineno
    attr_reader :charno
    attr_accessor :kind # Symbol. Can mutate from keyword to ident
    attr_accessor :text # String

    # Formatted reference for error messages
    def location() = "#{file} #{lineno}:#{charno}"

    # Value of token. Used by simple expressions to accumulate arguments
    attr_accessor :value

    def initialize(file, lineno, charno, text, kind)
      @file, @lineno, @charno, @text, @kind = file, lineno, charno, text, kind
    end

    def to_s = @text
    def inspect = "#<Token:#{kind} #{lineno}:#{charno} #{text.inspect}>"
    def dump = puts "#{kind} #{lineno}:#{charno} #{text.inspect}"
  end

  class DirToken < Token
    alias_method :path, :text

    def initialize(*file_args, dirname)
      @dirname = dirname
      super(*file_args, dirname, :DIR)
    end
  end

  class FileToken < Token
    alias_method :path, :text
    attr_reader :dirname
    attr_reader :filename
    attr_reader :extname

    def initialize(*file_args, path, dirname, filename, extname)
      super(*file_args, path, :FILE)
      @dirname, @filename, @extname = dirname, filename, extname
    end
  end

  class ErrorToken < Token
    alias_method :error, :text
    def error = nil

  protected
    def initialize(*file_args, error)
      super(*file_args, error, :ERROR)
    end
  end

  # Forwards everything to another token. Used when a token was parsed
  # correctly but of the wrong kind
  class TokenErrorToken < ErrorToken
    attr_reader :token
    forward_to :@token, :file, :lineno, :charno, :text
    alias_method :error, :text
    def initialize(token) @token = token end # No super!
  end

  # Pin-points position where an unexpected character was found
  class CharErrorToken < ErrorToken
    # Lazy-eval
    def charno = @charno || parse.first

    # Error character or string
    def error = @error || parse.last

    # The error message is lazy-evaluated because we may create error tokens
    # that will be ignored later so we don't want to spend time in vain on the
    # relatively expensive process of pin-pointing of the exact spot where the
    # error occurred
    def initialize(file, lineno, error_charno, text)
      super(file, lineno, nil, text)
      @error_charno = error_charno
    end

  protected
    # Returns [charno, char] for convenience
    def parse
      if m = ERROR_TOKEN_RE.match(@text)
        [ @charno = @error_charno + m.offset(:char).first, @error = m[:char] ]
      else
        [ @charno = @error_charno, @error = @text ]
      end
    end
  end
end

