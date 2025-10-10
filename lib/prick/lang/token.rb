
module Prick::Lang
  class Token
    # List of recognized file types. File types are reserved words and can't be
    # used as object name or even as values. That makes it possible to distinguish
    # between referencing a resource or referencing a known file type; other
    # file types have include a directory:
    #
    #   if file.sql? || ./file.any? || schema.resource?
    #
    EXTS = %w(sql psql rb fox prick)

    # Tokens. Maps from token kind to string or nil
    TOKENS = {
      # Top level keywords. Keywords are reserved, they can't be used as object
      # names or even as values (we don't have quoted string)
      PROGRAM: nil,
      SCHEMA: "schema",
      OPTION: "option",
      REQUIRE: "require",
      PROVIDE: "provide",
      FUNCTION: "function",
      RETURN: "return",

      # Phases. Phases are not keywords but builtin identifirs and can be
      # used in references
      INIT: "init",
      TERM: "term",
      META: "meta",
      SEED: "seed",
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

      # Punctuation
      BRACE_BEGIN: "{",
      BRACE_END: "}",
      COMMA: ",",

      # Continuation
      PIPE: "|",

      # Operators
      PAREN_BEGIN: "(",
      PAREN_END: ")",
      ANDAND: "&&",
      OROR: "||",
      LE: "<=", # Order is important because this matches against prefixes
      LT: "<",
      EQ: "=",
      NE: "!=",
      GE: ">=",
      GT: ">",
      TIGT: "~>", # 'TI' for tilde
      IN: "^",
      PCT: "%",
      NOT: "!",
      QUEST: "?",

      # Simple values
      TRUE: "true",
      FALSE: "false",

      # Identifiers and references
      IDENT: nil,
      REF: nil,

      # Variables
      VAR: nil,

      # Literals
      FILE: nil,
      DIR: nil,
      VER: nil, # Version number

      # Text literals
      LINE: nil, # Line of text
      TEXT: nil, # Multiple lines

      # Terminators. They are positioned one-beyond the end of line/block/file
      EOL: nil,
      EOB: nil, # End-of-block
      EOF: nil,

      # Artificial token that marks a list. Used in the parser
      LIST: nil,

      # Artificial token that marks a parentheses (that may be interpreted as a
      # single-element list)
      PAREN: nil,

      # Error
      ERROR: nil
    }

    # Token names are used in error messages: TOKEN entries that maps to a
    # string are enclosed in quotes, other tokens are defined below
    FORMATS = TOKENS.transform_values { "'#{_1}'" }.merge({
      TRUE: "true or false",
      FALSE: "true or false",
      IDENT: "identifier \"%s\"",
      REF: "reference \"%s\"",
      VAR: "variable %s",
      FILE: "file %s",
      DIR: "directory %s",
      VER: "version %s",
#     WORD: "file",
      LINE: "text '%s'",
      TEXT: "indented text '%s'",
      EOL: "end of line",
      EOB: "end of block",
      EOF: "end of file",
      LIST: "list",
      PAREN: "parenthesis"
    })

    # Maps from keyword/punctuation-character to kind. Inverse map of TOKENS
    # but excludes token that maps to nil
    TOKEN_KINDS = TOKENS.select { _2.is_a? String }.invert

    # Categories
    #
    # The following constants are lists of kinds that matches the given category. It
    # implements the following hierarchy. A token's category can be queried
    # using the #is_X? methods
    #
    # Variables can contain any set of characters but can only be compared
    # against valid names
    #
    #   token
    #     keyword
    #     value
    #       ref
    #         ident
    #           phase
    #       ver
    #       path
    #         file
    #         dir
    #       var # yields a value
    #     oper
    #       prefix
    #       infix
    #       suffix
    #     line
    #     text
    #     punct
    #
    KINDS = TOKENS.keys # List of all token kinds
    PATHS = [:PATH, :FILE, :DIR]
    PHASES = [:INIT, :TERM, :META, :SEED, :AUTH]
    BOOLS = [:TRUE, :FALSE]
    IDENTS = [:IDENT] + PHASES
    REFS = [:REF] + IDENTS
    VALUES = REFS + [:TRUE, :FALSE, :VER, :VAR] + PATHS
    KEYWORDS = TOKENS.select { _2 =~ /^\w+$/ }.keys
    PREFIX_OPERS = [:NOT]
    SUFFIX_OPERS = [:QUEST]
    INFIX_OPERS = [:ANDAND, :OROR, :LE, :LT, :EQ, :EQ, :NE, :GE, :GT, :TIGT, :IN, :PCT]
    OPERS = INFIX_OPERS + PREFIX_OPERS + SUFFIX_OPERS + [:PAREN_BEGIN, :PAREN_END] # Longest opers has to go first
    PUNCTS = [:BRACE_BEGIN, :BRACE_END, :COMMA, :PIPE] # List of punctuation characters

    RESERVED_WORDS = KEYWORDS + EXTS

    # *_PATTERN regular expressions do not generate captures
    KEYWORD_PATTERN = /\b#{Regexp.union KEYWORDS.map { TOKENS[_1] }}\b/
    PUNCT_PATTERN = /#{Regexp.union PUNCTS.map { TOKENS[_1] }}/
    OPER_PATTERN = /#{Regexp.union OPERS.map { TOKENS[_1] }}/
    FILE_PATTERN = /[^\/\s\0*?"`'$<>|:\[\]]+/ # Any legal linux filename
    EXT_PATTERN = Regexp.union(EXTS) # recognized file extensions
    RELDIR_PATTERN = /\.{1,2}\/|\// # initial '/', '../', or './'
    DIR_PATTERN = /#{RELDIR_PATTERN}?(?:#{FILE_PATTERN}\/)+/ # path ending in '/'
    BOOL_PATTERN = /\b#{Regexp.union BOOLS.map { TOKENS[_1] }}\b/
    IDENT_PATTERN = /[_a-zA-Z]\w*/ # language identifier
    REF_PATTERN = /#{IDENT_PATTERN}?\.#{IDENT_PATTERN}/
    VAR_PATTERN = /\$#{IDENT_PATTERN}/
    VER_PATTERN = /\d+(?:\.(\d+)(?:\.(\d+))?)?/

    # *_RE regular expressions generate captures
    KEYWORD_RE = /(?<keyword>#{KEYWORD_PATTERN})/
    PUNCT_RE = /(?<punct>#{PUNCT_PATTERN})/
    OPER_RE = /(?<oper>#{OPER_PATTERN})/
    FILE_RE = /(?<path>#{DIR_PATTERN})?(?<file>#{FILE_PATTERN}\.(?<ext>#{EXT_PATTERN}))/
    PATH_RE = /(?<path>#{DIR_PATTERN}#{FILE_PATTERN})/
    DIR_RE = /(?<dir>#{DIR_PATTERN})/
    BOOL_RE = /(?<bool>#{BOOL_PATTERN})/
    REF_RE = /(?<ref>#{REF_PATTERN})/
    VAR_RE = /(?<var>#{VAR_PATTERN})/
    IDENT_RE = /(?<ident>#{IDENT_PATTERN})/
    VER_RE = /(?<ver>#{VER_PATTERN})/

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
    TOKEN_RE = /
        #{VAR_RE}
        | #{KEYWORD_RE}
        | #{OPER_RE}      # Has to go before PUNCT_RE
        | #{PUNCT_RE}
        | #{DIR_RE}
        | #{FILE_RE}
        | #{PATH_RE}
        | #{REF_RE}
        | #{BOOL_RE}
        | #{IDENT_RE}
        | #{VER_RE}
        | #{ERROR_RE}
    /x

    WORD_RE = /\s*(?<word>\S+)/

    # Matches as far as possible in the string. This is the same as TOKEN_RE
    # except filesystem names that matches nearly everything. Note that while
    # ERROR_RE (included in TOKEN_RE) matches the whole failing string,
    # ERROR_TOKEN_RE is used to pin-point the character that made TOKEN_RE to
    # fail
    ERROR_TOKEN_RE = /^(?:#{VAR_PATTERN}|#{REF_PATTERN}|#{VER_PATTERN}|#{IDENT_PATTERN})(?<char>.)/

    attr_reader :file
    attr_reader :lineno
    attr_reader :charno
    attr_accessor :kind # Symbol
    attr_accessor :text # String

    # Formatted reference for error messages
    def location() = "#{file} #{lineno}:#{charno}"

    # Value of token. Used by simple expressions to accumulate arguments
    attr_accessor :value

    def initialize(file, lineno, charno, text, kind)
      @file, @lineno, @charno, @text, @kind = file, lineno, charno, text, kind
    end

    # Categories
    def is_keyword? = KEYWORDS.include? kind
    def is_value? = VALUES.include? kind
    def is_ref? = REFS.include? kind
    def is_ident? = IDENTS.include? kind
    def is_phase? = PHASES.include? kind
    def is_true? = kind == :TRUE
    def is_false? = kind == :FALSE
    def is_ver? = kind == :VER
    def is_path? = PATHS.include? kind
    def is_file? = kind == :FILE
    def is_dir? = kind == :DIR
    def is_var? = kind == :VAR
    def is_oper? = OPERS.include? kind
    def is_prefix_oper? = PREFIX_OPERS.include? kind
    def is_infix_oper? = INFIX_OPERS.include? kind
    def is_suffix_oper? = SUFFIX_OPERS.include? kind
    def is_line? = kind == :LINE
    def is_text? = kind == :TEXT
    def is_punct? = PUNCTS.include? kind
    def is_list? = kind == :LIST
    def is_paren? = kind == :PAREN

    # Format for token in error messages. '%s' may be used as expansion of
    # #text
    def format = FORMATS[kind]

    def to_s = @text
    def inspect = "#<Token:#{kind} #{lineno}:#{charno} #{text.inspect}>"
    def dump = puts "#{kind} #{lineno}:#{charno} #{text.inspect}"
  end

  class ListToken < Token
    attr_accessor :size
    def initialize(token, size = 1)
      constrain token, Token
      constrain token.kind, :PAREN_BEGIN
      super(token.file, token.lineno, token.charno, token.text, :LIST)
      @size = size
    end
    def to_s = "[#{size}]"
    def inspect = "#<Token:#{kind} #{lineno}:#{charno} #{text.inspect} #{size}>"
  end

  class ParenToken < Token
    attr_accessor :empty
    def empty? = empty
    def initialize(token, empty = false)
      super(token.file, token.lineno, token.charno, token.text, :PAREN)
      @empty = false
    end
    def to_s = empty? ? "(0)" : "(1)"
  end

  class VarToken < Token
    attr_reader :name
    def initialize(file, lineno, charno, text)
      super(file, lineno, charno, text, :VAR)
      @name = text[1..-1]
    end
  end

  class DirToken < Token
    alias_method :path, :text

    def initialize(*file_args, dirpath)
      super(*file_args, dirpath, :DIR)
    end
  end

  class PathToken < Token
    alias_method :path, :text

    def initialize(*file_args, path)
      super(*file_args, path, :DIR)
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
#   alias_method :error, :text
#   def error = nil
    def initialize(*file_args, text)
      super(*file_args, text, :ERROR)
    end
  end

  # Forwards everything to another token. Used when a token was parsed
  # correctly but of the wrong kind
# class TokenErrorToken < ErrorToken
#   attr_reader :token
#   forward_to :@token, :file, :lineno, :charno, :text
#   alias_method :error, :text
#   def initialize(token) @token = token end # No super!
# end

  # Pin-points position where an unexpected character was found
# class CharErrorToken < ErrorToken
#   # Lazy-eval
#   def charno = @charno || parse.first
#
#   # Error character or string
#   def error = @error || parse.last
#
#   # The error message is lazy-evaluated because we may create error tokens
#   # that will be ignored later so we don't want to spend time in vain on the
#   # relatively expensive process of pin-pointing of the exact spot where the
#   # error occurred
#   def initialize(file, lineno, error_charno, text)
#     super(file, lineno, nil, text)
#     @error_charno = error_charno
#   end
#
# protected
#   # Returns [charno, char] for convenience
#   def parse
#     if m = ERROR_TOKEN_RE.match(@text)
#       [ @charno = @error_charno + m.offset(:char).first, @error = m[:char] ]
#     else
#       [ @charno = @error_charno, @error = @text ]
#     end
#   end
# end
end

