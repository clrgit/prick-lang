
describe "Prick::Lang" do
  # Token *_RE constants by name (symbol) so save a lot of typing
  def re(re_symbol, eol: true) = /^#{Prick::Lang::Token.const_get(re_symbol)}#{eol ? '$' : ''}/

  describe "Token" do
    # Lazy match check
    def e(re_symbol, string, eol: true)
      expect(string).to match re(re_symbol, eol: eol)
    end

    def not_e(re_symbol, string, eol: true)
      expect(string).not_to match re(re_symbol, eol: eol)
    end

    # Lazy capture check
    def c(re_symbol, source, capture, text = source, eol: true)
      expect(re(re_symbol, eol: eol).match(source)[capture]).to eq text
    end

    describe "::KEYWORD_RE" do
      it "matches whole words" do
        not_e :KEYWORD_RE, "schema1", eol: false
      end

      it "matches keywords" do
        e :KEYWORD_RE, "schema"
      end

      it "sets 'keyword' capture" do
        c :KEYWORD_RE, "schema", :keyword
      end
    end

    describe "::PUNCT_RE" do
      it "matches prefixes" do
        e :PUNCT_RE, "<<", eol: false
      end

      it "matches punctuation" do
        e :PUNCT_RE, "{"
      end

      it "sets 'punct' capture" do
        c :PUNCT_RE, "{", :punct
      end
    end

    describe "::DIR_RE" do
      it "matches directory names" do
        e :DIR_RE, "name/"
      end
      it "matches directory paths" do
        e :DIR_RE, "dir/name/"
      end
      it "matches relative paths" do
        e :DIR_RE, "./dir/name/"
        e :DIR_RE, "../dir/name/"
      end
      it "matches absolute paths" do
        e :DIR_RE, "/dir/name/"
      end
      it "sets 'dir' capture" do
        c :DIR_RE, "dir/name/", :dir
      end
    end

    describe "::FILE_RE" do
      it "matches known file types" do
        e :FILE_RE, "name.sql"
      end
      it "matches paths" do
        e :FILE_RE, "dir/name.sql"
      end
      it "sets 'path' capture" do
        c :FILE_RE, "dir/name/file.sql", :path, "dir/name/"
      end
      it "sets 'file' capture" do
        c :FILE_RE, "dir/name/file.sql", :file, "file.sql"
      end
      it "sets 'ext' capture" do
        c :FILE_RE, "dir/name/file.sql", :ext, "sql"
      end
      it "matches only one filename" do
        c :FILE_RE, "a.sql b.sql", :file, "a.sql", eol: false
      end
    end

    describe "::IDENT_RE" do
      it "matches identifiers" do
        e :IDENT_RE, "id"
        e :IDENT_RE, "id1243"
        e :IDENT_RE, "_id1243"
      end
      it "sets 'ident' capture" do
        c :IDENT_RE, "id", :ident
      end
    end

    describe "::OBJREF_RE" do
      it "matches object references" do
        e :OBJREF_RE, "root.branch.leaf"
      end
      it "sets the 'objref' capture" do
        c :OBJREF_RE, "root.branch.leaf", :objref
      end
    end

    describe "::GRPREF_RE" do
      it "matches group references" do
        e :GRPREF_RE, "root::branch::leaf"
      end
      it "sets the 'grpref' capture" do
        c :GRPREF_RE, "root::branch::leaf", :grpref
      end
    end

    describe "::VERSION_RE" do
      it "matches versions" do
        e :VERSION_RE, "1.2.3"
      end
      it "sets the 'version' capture" do
        c :VERSION_RE, "1.2.3", :version
      end
    end

    describe "::TOKEN_RE" do
      it "sets the 'keyword' capture" do
        c :TOKEN_RE, "schema", :keyword
      end
      it "sets the 'punct' capture" do
        c :TOKEN_RE, "{", :punct
      end
      it "sets the 'dir' capture" do
        c :TOKEN_RE, "./name/dir/", :dir
      end
      it "sets 'path' capture" do
        c :TOKEN_RE, "dir/name/file.sql", :path, "dir/name/"
      end
      it "sets 'file' capture" do
        c :TOKEN_RE, "dir/name/file.sql", :file, "file.sql"
      end
      it "sets 'ext' capture" do
        c :TOKEN_RE, "dir/name/file.sql", :ext, "sql"
      end
      it "sets 'ident' capture" do
        c :TOKEN_RE, "id", :ident
      end
      it "sets the 'objref' capture" do
        c :TOKEN_RE, "root.branch.leaf", :objref
      end
      it "sets the 'grpref' capture" do
        c :TOKEN_RE, "root::branch::leaf", :grpref
      end
      it "sets the 'version' capture" do
        c :TOKEN_RE, "1.2.3", :version
      end
    end

    describe "::ERROR_RE" do
      it "matches a group of non-space characters" do
        e :ERROR_RE, "error"
      end
    end

    describe "::ERROR_TOKEN_RE" do
      it "match the character that caused the error" do
        c :ERROR_TOKEN_RE, "asdf*", :char, '*'
      end
    end
  end

  describe "CharErrorToken" do
    def make(s) = Prick::Lang::CharErrorToken.new("file.sql", 1, 3, s)

    describe "#charno" do
      def charno(s) = make(s).charno

      def e(s, pos)
        expect(charno(s)).to eq pos
      end

      it "is the postion of the error" do
        e "@", 3
      end

      context "scan" do
        it "words" do e "word@", 7 end
        it "integers" do e "1234.", 7 end
        it "identifiers" do e "ident@", 8 end
        it "references" do
          s = "root.branch.leaf@error"
          e s, 3 + s.index('@')
        end
      end
    end

    describe "#char" do
      def error(s) = make(s).error
      def e(s, c) = expect(error(s)).to eq c

      it "is the error character" do
        e "word@", "@"
      end
      it "...or string" do
        e ".word", ".word"
      end
    end
  end
end
__END__
    # Token *_RE constants by name (symbol) so save a lot of typing
    def re(re_symbol) = /^#{Prick::Lang::Token.const_get(re_symbol)}$/

    # Lazy match check
    def e(re_symbol, string)
      expect(string).to match re re_symbol
    end

    # Lazy capture check
    def c(re_symbol, source, capture, text = source) = expect(re(re_symbol).match(source)[capture]).to eq text

