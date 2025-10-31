
describe "Prick::Lang" do
  using String::Text

  describe "Reader" do
    class Prick::Lang::Reader
      attr_accessor :index, :pos, :token, :error
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

      it "handles multiple tokens on a line" do
        r = make ["word1 word2"]
        expect(r.read.text).to eq "word1"
        expect(r.read.text).to eq "word2"
      end

      it "ignores empty lines and comments X" do
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

    describe "#readline" do
      def call(l) = make(l).readline

      it "returns a LINE token with the rest of the line" do
        r = make ["word more words"]
        r.read
        t = r.readline
        expect(t.kind).to eq :LINE
        expect(t.text).to eq "more words"
      end

      it "advances the reader" do
        r = make ["word more words"]
        r.read
        r.readline
        expect(r.eol?).to eq true
      end

      it "sets #token" do
        r = make ["more words"]
        t = r.readline
        expect(r.token).to eq t
      end

      it "resets #error" do
        r = make ["more words"]
        r.error = "VALUE"
        t = r.readline
        expect(r.error).to eq nil
      end

      context "when at EOL" do
        it "returns nil" do
          r = make ["word"]
          r.read
          expect(r.readline).to eq nil
        end
        it "resets #token" do
          r = make ["word"]
          r.read
          r.readline
          expect(r.error.kind).to eq :EOL
        end
        it "sets #error to EOL" do
          r = make ["word"]
          r.read
          r.readline
          expect(r.error.kind).to eq :EOL
        end

        context "when :eol is true" do
          it "returns a EOL token" do
            r = make ["word"]
            r.read
            expect(r.readline(eol: true).kind).to eq :EOL
          end

          it "sets #token" do
            r = make ["word"]
            r.read
            t = r.readline(eol: true)
            expect(r.token).to eq t
          end
          it "resets #error" do
            r = make ["word"]
            r.read
            r.error = "ERROR"
            r.readline(eol: true)
            expect(r.error).to eq nil
          end
        end
      end

      context "when at EOF" do
        it "returns nil" do
          r = make [""]
          r.read
          expect(r.readline).to eq nil
        end
        it "resets #token" do
          r = make [""]
          r.read
          r.readline
          expect(r.token).to eq nil
        end
        it "sets #error" do
          r = make [""]
          r.read
          r.readline
          expect(r.error.kind).to eq :EOF
        end
        context "when :eof is true" do
          it "returns a EOF token" do
            r = make [""]
            r.read
            t = r.readline(eof: true)
            expect(t.kind).to eq :EOF
          end
          it "sets #token" do
            r = make [""]
            r.read
            t = r.readline(eof: true)
            expect(r.token).to eq t
          end
          it "resets #error" do
            r = make [""]
            r.read
            r.error = "ERROR"
            r.readline(eof: true)
            expect(r.error).to eq nil
          end
        end
      end
    end

    describe "#readtext" do
      def call(l) = make(l).readtext
      it "returns a TEXT token" do
        l = %(
          exec
            line1
            line2
          line3
        ).align
        r = make(l)
        r.read # exec token
        t = r.readtext(0)
        expect(t.kind).to eq :TEXT
        expect(t.text).to eq "line1\nline2"
      end

      context "when not found" do
        def reader(&block)
          l = %(
            exec
            line3
          ).align
          r = make(l)
          r.read # exec token
          yield r
        end

        it "returns nil" do
          reader { |r|
            t = r.readtext(0)
            expect(t).to eq nil
          }
        end
        it "resets #token" do
          reader { |r|
            r.token = "TOKEN"
            t = r.readtext(0)
            expect(r.token).to eq nil
          }
        end
        it "sets #error to an EOB token" do
          reader { |r|
            r.token = "TOKEN"
            r.readtext(0)
            expect(r.error.kind).to eq :EOB
          }
        end
      end

      context "when at EOF" do
        def reader(&block)
          l = %(
            exec
          ).align
          r = make(l)
          r.read # exec token
          yield r
        end

        it "returns nil" do
          reader { |r|
            expect(r.readtext(0)).to eq nil
          }
        end

        it "resets #token" do
          reader { |r|
            r.token = "TOKEN"
            r.readtext(0)
            expect(r.token).to eq nil
          }
        end

        it "sets #error to an EOF token" do
          reader { |r|
            r.token = "TOKEN"
            r.readtext(0)
            expect(r.error.kind).to eq :EOF
          }
        end

        context "when :eof is true" do
          it "returns an EOF token" do
            reader { |r|
              t = r.readtext(0, eof: true)
              expect(t.kind).to eq :EOF
            }
          end
          it "sets #token" do
            reader { |r|
              t = r.readtext(0, eof: true)
              expect(r.token).to eq t
            }
          end
          it "resets #error" do
            reader { |r|
              r.error = "ERROR"
              t = r.readtext(0, eof: true)
              expect(r.error).to eq nil
            }
          end
        end
      end
    end

    describe "#readeol" do
      it "returns an EOL token" do
        r = make [""]
        expect(r.readeol.kind).to eq :EOL
      end
      it "sets #token"
      it "resets #error"

      context "when not at EOL" do
        it "returns nil" do
          r = make ["word"]
          expect(r.readeol).to eq nil
        end
        it "sets #error" do
          r = make ["word"]
          r.readeol
          expect(r.error.text).to eq "word"
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
        r = make ["word1 word2"]
        r.pos = 5
        r.scan
        expect(r.index).to eq 0
        expect(r.pos).to eq 6
      end

      it "ignores EOL" do
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


__END__
      it "handles multiple tokens on a line" do
        r = make ["word1 word2"]
        expect(r.read.text).to eq "word1"
        r.dump
        expect(r.read.text).to eq "word2"
      end




















