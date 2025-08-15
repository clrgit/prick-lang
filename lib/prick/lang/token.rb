
module Prick::Lang
  class Token
    KEYWORDS = %w(schema options if elsif else case when init term meta seeds auth exec eval ruby sql psql)
    PUNCT = %w({ })

    KEYWORD_KINDS = KEYSWORDS.map(&:upcase).map(&:to_sym)
    PUNCT_KINDS = %w(BLOCK_BEGIN BLOCK_END).map(&:to_sym)
    INTERN = %w(TEXT).map(&:to_sym)

    KINDS = KEYWORD_KINDS + PUNCT_KINDS + INTERN

    # Maps from keyword/punctuation to kind
    WORDS = ((KEYWORDS + PUNCT).zip(KEYWORD_KINDS + PUNCT_KIND).to_h)

    attr_accessor :kind # String
    attr_accessor :text
    attr_accessor :file
    attr_accessor :lineno
    attr_accessor :charno

    def initialize(file, lineno, charno, kind, text)
      @file, @lineno, @charno, @kind, @text = file, lineno, charno, kind, text
    end
  end
end

