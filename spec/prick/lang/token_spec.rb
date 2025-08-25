
describe "Prick::Lang" do
  # Token *_RE constants by name (symbol) so save a lot of typing
  def re(re_symbol) = /^#{Prick::Lang::Token.const_get(re_symbol)}$/

  describe "Token" do
    # Lazy match check
    def e(re_symbol, string)
      expect(string).to match re re_symbol
    end

    # Lazy capture check
    def c(re_symbol, source, capture, text = source) = expect(re(re_symbol).match(source)[capture]).to eq text

    describe "::WORD_RE" do
      it "matches keywords" do
        e :WORD_RE, "schema"
      end

      it "matches punctuation" do
        e :WORD_RE, "{"
      end

      it "sets 'word' capture" do
        c :WORD_RE, "schema", :word
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
    end

    describe "::INT_RE" do
      it "matches integers" do
        e :INT_RE, "1234"
      end
      it "sets 'int' capture" do
        c :INT_RE, "1234", :int
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

    describe "::REF_RE" do
      it "matches references" do
        e :REF_RE, "root.branch.leaf"
      end
      it "sets the 'ref' capture" do
        c :REF_RE, "root.branch.leaf", :ref
      end
    end

    describe "::ERROR_RE" do
      it "matches a group of non-space characters" do
        e :ERROR_RE, "error"
      end
    end

    describe "::TOKEN_RE" do
      it "sets the 'word' capture" do
        c :TOKEN_RE, "schema", :word
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
      it "sets the 'ref' capture" do
        c :TOKEN_RE, "root.branch.leaf", :ref
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
        it "word" do e "word@", 7 end
        it "int" do e "1234.", 7 end
        it "ident" do e "ident@", 8 end
        it "ref" do
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

