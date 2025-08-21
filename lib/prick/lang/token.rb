
module Prick::Lang
  class Token
    TOKENS = {
      PROGRAM: nil, # FIXME "program"
      SCHEMA: "schema",
      OPTION: "option",
      REQUIRE: "require",
      INIT: "init",
      TERM: "term",
      META: "meta",
      SEEDS: "seeds",
      AUTH: "auth",
      GROUP: "group",
      IF: "if",
      ELSE: "else",
      ELSIF: "elsif",
      CASE: "case",
      WHEN: "when",
      EXEC: "exec",
      EVAL: "eval",
      RUBY: "ruby",
      SQL: "sql",
      FILE: nil, # FIXME "file"
      ENV: "env",
      CMD: "cmd",
      NOT: "not",

      BRACE_BEGIN: "{", # is not related to the BRACE token
      BRACE_END: "}",
      PIPE: "|", # TODO: Eliminate or make optional

      TEXT: nil,
      LINE: nil,
      BLOCK: nil
    }

    # List of token kinds
    KINDS = TOKENS.keys

    # List of keywords and punctuation characters
    WORDS = TOKENS.values.compact

    # Regular expression matching a keyword. Note that this also matches
    # undefined words
#   KEYWORD_RE = /\w+/
    KEYWORD_RE = /[\w.]+/

    # List of keyword strings
    KEYWORDS = WORDS.select { _1 =~ KEYWORD_RE }

    # List of punctuation strings
    PUNCTS = WORDS - KEYWORDS

    # Punctuation
    PUNCT_RE = Regexp.union *PUNCTS

    # A single non-space character
    CHAR_RE = /\S/

    WORD_RE = Regexp.union KEYWORD_RE, PUNCT_RE, CHAR_RE

    attr_accessor :file
    attr_accessor :lineno
    attr_accessor :charno
    attr_accessor :kind # Symbol
    attr_accessor :text # String

    # Only defined for :FILE tokens. TODO: Make into a general PrickPath object
    attr_accessor :filename
    attr_accessor :extname

    def initialize(file, lineno, charno, text, kind = nil, filename = nil, extname = nil)
      @file, @lineno, @charno, @text, @kind, @filename, @extname =
          file, lineno, charno, text, kind, filename, extname
#     @kind, @filename, @extname = *(kind ? [kind, filename, extname] : Token.args(text))
    end

    # Return true if token belongs to the given grammar group (see parse.rb)
    def group?(group) = Tokenizer::GRAMMAR_GROUPS[group].include?(kind)

    def to_s = @text
    def inspect = "#<Token:#{kind} #{lineno} #{text.inspect}>"

#   def self.kind(text)
#     MAP[text] or (File.basename(text) =~ FILENAME_RE ? :FILE : :TEXT)
#   end

#   def self.args(text)
#     if kind = MAP[text]
#       [kind]
#     elsif File.basename(text) =~ FILENAME_RE
#       [:FILE, $1, $2]
#     else
#       [:TEXT]
#     end
#   end
  end
end

