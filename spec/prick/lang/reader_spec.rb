
describe "Prick::Lang" do
  using String::Text

  describe "Reader" do
    class Prick::Lang::Reader
      attr_accessor :index, :pos
    end

    def file = "file.txt" # Considered a constanta

    def make(lines)
      lines = lines.align(empty: true).split("\n", -1) if lines.is_a?(String)
      Prick::Lang::Reader.new(file, lines)
    end

    describe "#eof?" do
      it "is true at EOF" do
        l = %()
        expect(make(l).eof?).to eq true
      end
      it "only reflects the current position" do
        l = %(
        )
        expect(make(l).eof?).to eq false
      end
    end

    describe "#eol?" do
      it "is true at EOL" do
        l = %(
        )
        expect(make(l).eol?).to eq true
      end
      it "is true at EOF" do
        l = %()
        expect(make(l).eol?).to eq true
      end
      it "only reflects the current position" do
        r = make ["  "]
        expect(r.eof?).to eq false
      end
    end

    describe "#read" do
      def call(l, **opts) = make(l).read(**opts)

      it "returns a token" do
        t = call ["word"]
        expect(t).to be_a Prick::Lang::Token
        expect(t.lineno).to eq 1
        expect(t.charno).to eq 1
        expect(t.text).to eq "word"
      end

      it "returns nil if not found" do
        t = call [""]
        expect(t).to eq nil
      end

      it "sets #token if found" do
        r = make ["word"]
        t = r.read
        expect(r.token).to eq t
      end

      it "sets #error it not found" do
        r = make ["word"]
        r.read
        r.read
        expect(r.error).to be_a Prick::Lang::Token
      end

      it "moves the reader forward" do
        r = make ["word"]
        t = r.read
        expect(r.eol?).to eq true
      end

      it "ignores empty lines and comments" do
        r = make %(

          # comment
            word
        )
        t = r.read
        expect(t.lineno).to eq 4
        expect(t.charno).to eq 3
        expect(r.index).to eq 3
        expect(r.pos).to eq 6
      end

      context "recognizes" do
        def kind(s) = call(s).kind

        it "keywords" do expect(kind("if")).to eq :IF end
        it "punctuation" do expect(kind(",")).to eq :COMMA end
        it "operators" do expect(kind("!=")).to eq :NE end
        it "filenames" do expect(kind("file.sql")).to eq :FILE end
        it "directories" do expect(kind("dir/")).to eq :DIR end
        it "paths" do expect(kind("/dir/file.unknown")).to eq :PATH end
        it "identifiers" do expect(kind("word")).to eq :IDENT end
        it "references" do expect(kind("ref.ref")).to eq :REF end
        it "boolean values" do expect(kind("true")).to eq :TRUE end
        it "version values" do expect(kind("1.2.3")).to eq :VER end
      end

      context "when at EOL" do
        it "ignores EOL" do
          r = make %(
            word1
            word2
          )
          r.read
          expect(r.read.text).to eq "word2"
        end

        context "when :eol is true" do
          def call(l) = make(l).read(eol: true)

          it "returns a EOL token" do
            r = make %w(word1 word2)
            t0 = r.read(eol: true)
            t = r.read(eol: true)
            expect(t.kind).to eq :EOL
          end

          it "sets #token to EOL token" do
            r = make [""]
            t = r.read
            expect(r.token).to eq t
          end

          it "advances the reader" do
            r = make [""]
            r.read
            expect(r.eof?).to eq true
          end

        end
      end

      context "when at EOF" do
        it "returns nil" do
          r = make [""]
          expect(r.read).to eq nil
        end
        it "sets #error to EOF token" do
          r = make [""]
          r.read
          expect(r.error.kind).to eq :EOF
        end

        context "when :eol is true" do
          it "initially returns a EOL token" do
            t = call [""], eol: true
            expect(t.kind).to eq :EOL
          end
          it "then it returns nil" do
            r = make [""]
            r.read eol: true
            t = r.read eol: true
            expect(t).to eq nil
          end
          it "and sets #error" do
            r = make [""]
            r.read eol: true
            r.read eol: true
            expect(r.error.kind).to eq :EOF
          end
        end

        context "when :eof is true" do
          def call(l) = make(l).read(eof: true)
          it "returns a EOF token" do
            r = make [""]
            t = r.read eof: true
            expect(t.kind).to eq :EOF
          end
          it "does not advance the reader" do
            r = make [""]
            r.read eof: true
            index = r.index
            r.read eof: true
            expect(r.index).to eq index
          end
        end
      end
    end

    describe "#scan" do
      def call(l) = make(l).scan

      it "scans blanks" do
        r = call ["  t"]
        expect(r.pos).to eq 2
      end

      it "scans empty lines" do
        r = call ["", "", "t"]
        expect(r.index).to eq 2
      end

      it "scans comments" do
        r = call ["", "#", "t"]
        expect(r.index).to eq 2
      end

      it "scans rest of line" do
        r = make ["word"]
        r.pos = 4
        r.scan
        expect(r.index).to eq 1
      end

      it "sets pos to the first non-blank, non-comment character" do
        r = call ["", "  t"]
        expect(r.pos).to eq 2
      end

      context "when eol: true" do
        def call(l) = make(l).scan(eol: true)

        it "stops a EOL" do
          r = call ["  ", "t"]
          expect(r.index).to eq 0
          expect(r.pos).to eq 2
          expect(r.eol?).to eq true
          expect(r.eof?).to eq false
        end
      end
    end
  end
end





















