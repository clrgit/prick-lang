
module Prick::Lang
  class Tokenizer
    # Return rest of line
    def rest = @lines[@index][@pos..-1]

    # Set end of line (but not eof)
    def eol!() @pos = line&.size || 0 end

    # Set eof (and eol)
    def eof!() @index, @pos = @lines.size, 1 end

    public :scanlines

    attr_reader :peek_index
    attr_reader :peek_pos
  end
end

describe "Prick::Lang" do
  using String::Text

  describe "Tokenizer" do
    def file = "file.txt" # Considered a constant

    def make(lines)
#     lines = lines.split "\n", -1
#     allow(IO).to receive(:readlines).with('file.txt').and_return(lines)
      Prick::Lang::Tokenizer.new(file, lines)
    end

    describe "#initialize" do
      it "skips trailing blanks" do
        l = ["a", "  ", "b"]
        t = make l
        expect(t.instance_eval("@lines")[1]).to eq ""
      end
      it "skips trailing empty lines" do
        l = ["a", "  "]
        t = make l
        expect(t.instance_eval("@lines").size).to eq 1
      end
      it "skips trailing comment-only lines" do
        l = ["a", "  # comment"]
        t = make l
        expect(t.instance_eval("@lines").size).to eq 1
      end
    end

    describe "#peek" do
      def call(lines) = make(lines).peek

      it "ignores initial empty lines" do
        l = ["", "exec"]
        expect(call(l).kind).to eq :EXEC
      end

      it "ignores initial blank lines" do
        l = ["   ", "exec"]
        expect(call(l).kind).to eq :EXEC
      end

      it "ignores initial comment-only lines" do
        l = [" # not exec", "exec"]
        expect(call(l).kind).to eq :EXEC
      end

      it "returns the same object on repeated calls" do
        l = %w(exec)
        t = make l
        tk1 = t.peek
        tk2 = t.peek
        expect(tk1).to eq tk2
      end

      it "advances to the next line if end of line after match" do
        l = %w(exec eval)
        t = make l
        t.peek
        expect(t.instance_eval "@peek_index").to eq 1
      end

      context "when at EOL" do
        it "returns an EOL token if :eol is true" do
          l = ["exec "]
          t = make(l)
          t.read(eol: true)
          expect(t.peek(eol: true).kind).to eq :EOL
        end
        it "returns the next token if :eol is false" do
          l = ["exec", "eval"]
          t = make(l)
          t.read(eol: false)
          expect(t.peek(eol: false).kind).to eq :EVAL
        end
      end
      context "when at EOF" do
        it "returns an EOF token if :eof is true" do
          l = ["exec "]
          t = make(l)
          t.read(eof: true)
          expect(t.peek(eof: true).kind).to eq :EOF
        end
        it "returns a EOL and then a EOF if both :eol and :eof is true" do
          l = ["exec "]
          t = make(l)
          opts = { eol: true, eof: true }
          t.read
          expect(t.peek(**opts ).kind).to eq :EOL
          t.read
          expect(t.peek(**opts).kind).to eq :EOF
        end
      end
    end

    describe "#read" do
      def call(lines) = make(lines).read
      def kind(lines) = call(lines)&.kind

      it "reads keyword tokens" do
        l = ["  exec", "eval"]
        expect(kind l).to eq :EXEC
      end

      it "reads identifiers" do
        l = ["  schema1"]
        expect(kind l).to eq :IDENT
      end

      it "reads file tokens" do
        l = ["t.sql"]
        expect(kind l).to eq :FILE
      end

      it "moves the position" do
        l = ["exec eval"]
        t = make l
        t.read
        expect(t.lineno).to eq 1
        expect(t.charno).to eq 6
      end

      it "advances to the next line if end of line after match" do
        l = %w(exec eval)
        t = make l
        t.read
        expect(t.lineno).to eq 2
        t.read
        expect(t.lineno).to eq 3
      end

      it "clears the read-ahead token" do
        l = %w(exec eval)
        t = make l
        t.peek
        expect(t.peek?).to eq true
        t.read
        expect(t.peek?).to eq false
      end

      context "when unknown/unexpected token" do
        it "returns nil" do
          l = ["£word"]
          t = make l
          expect(t.read).to eq nil
        end

        it "sets #error_token" do
          l = ["£word"]
          t = make l
          t.read
          expect(t.error.text).to eq "£word"
        end
      end

      context "when at EOL" do
        it "returns next token" do
          l = %w(exec eval)
          t = make l
          t.eol!
          expect(t.read.kind).to eq :EVAL
        end
        it "returns next token if :eol is false" do
          l = %w(exec eval)
          t = make l
          t.eol!
          expect(t.read(eol: false).kind).to eq :EVAL
        end
        it "returns a EolToken if :eol is true" do
          l = %w(exec eval)
          t = make l
          t.eol!
          expect(t.read(eol: true).kind).to eq :EOL
        end
      end

      context "when at EOF" do
        it "returns nil" do
          l = %w(exec)
          t = make l
          t.eof!
          expect(t.read).to eq nil
        end
        it "returns nil if :eof is false" do
          l = %w(exec)
          t = make l
          t.eof!
          expect(t.read(eof: false)).to eq nil
        end
        it "returns a EofToken if :eof is true" do
          l = %w(exec)
          t = make l
          t.eof!
          expect(t.read(eof: true).kind).to eq :EOF
        end
        it "returns a EOL and then a EOF token if both :eol and :eof is true" do
          l = ["exec "]
          t = make(l)
          opts = { eol: true, eof: true }
          t.read
          expect(t.read(**opts ).kind).to eq :EOL
          expect(t.read(**opts).kind).to eq :EOF
        end
      end
    end

    describe "#readline" do
      def call(lines, **opts) = make(lines).readline(**opts)

      it "returns rest of line as a LINE token" do
        l = ["exec a b c"]
        t = make l
        t.read
        expect(t.readline.text).to eq "a b c"
      end

      it "advances to the next line" do
        l = %w(exec eval)
        t = make l
        t.readline
        expect(t.lineno).to eq 2
      end

      it "sets eof after last line" do
        l = %w(exec)
        t = make l
        t.readline
        expect(t.eof?).to eq true
      end

      it "clears the read-ahead token" do
        l = %w(exec eval)
        t = make l
        t.peek
        expect(t.peek?).to eq true
        t.readline
        expect(t.peek?).to eq false
      end

      context "when at EOL" do
        it "returns nil" do
          l = %w(exec eval)
          t = make l
          t.eol!
          expect(t.readline).to eq nil
        end
        it "returns nil if :eol is false" do
          l = %w(exec eval)
          t = make l
          t.eol!
          expect(t.readline(eol: false)).to eq nil
        end
        it "returns a EolToken if :eol is true" do
          l = %w(exec eval)
          t = make l
          t.eol!
          expect(t.readline(eol: true).kind).to eq :EOL
        end
      end

      context "when at EOF" do
        # context ":eof is false (the default)" do
        #   it "returns nil" do
        #     # test default :eof
        #     # test explicit :eof
        #   end
        #   it "sets #error to EofToken"
        # end
        it "returns nil" do
          l = %w(exec)
          t = make l
          t.eof!
          expect(t.readline).to eq nil
        end
        it "returns nil if :eof is false" do
          l = %w(exec)
          t = make l
          t.eof!
          expect(t.readline(eof: false)).to eq nil
        end
        it "sets #error to EofToken (when nil)"
        it "returns a EofToken if :eof is true" do
          l = %w(exec)
          t = make l
          t.eof!
          expect(t.readline(eof: true).kind).to eq :EOF
        end
      end
    end

    describe "#readtext" do
      def call(lines, **opts) = make(lines).readtext(2, **opts)
      def text(lines) = call(lines).text

      it "raises if not bol?" do
        t = make ["a", "b"]
        t.eol!
        expect { t.readtext(2) }.to raise_error Prick::Lang::InternalError
      end

      it "returns a TEXT token" do
        l = ["  a", "  b"]
        expect(call(l).kind).to eq :TEXT
      end

      it "sets token file/lineno/charno" do
        l = ["  a", "  b"]
        tk = call l
        expect(tk.file).to eq file
        expect(tk.lineno).to eq 1
        expect(tk.charno).to eq 3
      end

      it "sets token text to the concanation of lines" do
        l = ["  a", "  b"]
        expect(text l).to eq "a\nb"
      end

      it "ignores leading blank lines" do
        l = ["", "  a"]
        expect(text l).to eq "a"
      end

      it "ignores trailing blank lines" do
        l = ["", "  a", ""]
        expect(text l).to eq "a"
      end

      it "keeps internal blank lines" do
        l = ["  a", "", "  b"]
        expect(text l).to eq "a\n\nb"
      end

      it "turns unindented comments into blank lines" do
        l = ["", "  a", "# comment", "  b"]
        expect(text l).to eq "a\n\nb"
      end

      it "keeps indented comments" do
        l = ["", "  a", "  # comment", "  b"]
        expect(text l).to eq "a\n# comment\nb"
      end

#     it "handles non-indented comments X" do
#       l = ["", "    a", "    b", "# comment", "  c"]
#       tk = make(l)
#       p tk.readtext(4)
#       p tk.read
#       tk.dump
#       exit
#       expect(text l).to eq "a\n# comment\nb"
#     end

      it "aligns to the least indented non-blank line" do
        l = ["", "    a", "", "  b"]
        expect(text l).to eq "  a\n\nb"
      end

      it "advances to the next line" do
        l = ["  a", "  b", "c"]
        t = make l
        t.readtext(2)
        expect(t.read.text).to eq "c"
      end

      it "clears the read-ahead token" do
        l = ["  a", "  b"]
        t = make l
        t.peek
        expect(t.peek?).to eq true
        t.readtext(2)
        expect(t.peek?).to eq false
      end

      context "when not at BOL" do
        it "raises an InternalError" do
          l = ["a", "  b"]
          t = make l
          t.eol!
          expect { t.readtext(2) }.to raise_error Prick::Lang::InternalError
        end
      end

      context "when at EOF" do
        it "returns nil" do
          l = %w(exec)
          t = make l
          t.eof!
          expect(t.readtext(2)).to eq nil
        end
        it "returns nil if :eof is false" do
          l = %w(exec)
          t = make l
          t.eof!
          expect(t.readtext(2, eof: false)).to eq nil
        end
        it "sets #error to EofToken"
        it "returns a EofToken if :eof is true" do
          l = %w(exec)
          t = make l
          t.eof!
          expect(t.readtext(2, eof: true).kind).to eq :EOF
        end
      end
    end

    describe "#scanlines" do
      def call(lines) = make(lines).scanlines(0, 0)

      it "skips single empty line" do
        l = ["", "a"]
        expect(call l).to eq [1, 0]
      end

      it "skips multiple empty lines" do
        l = ["", "", "a"]
        expect(call l).to eq [2, 0]
      end

      it "returns the index of the first non-empty line" do
        l = ["", "", "a", "", "b"]
        expect(call l).to eq [2, 0]
      end

      context "when :comment is false (the default)" do
        it "ignores leading comments" do
          l = ["# comment", "b"]
          expect(call l).to eq [1, 0]
        end

        it "resets peek_pos" do
          l = %(
              eval
                ls -l
                echo
              # comment
            }
          ).align.split("\n")
          tk = make(l)
          tk.read
          tk.readtext(4)
          tk.peek
          expect(tk.peek_pos).to eq 0
          expect(tk.peek.kind).to eq :BRACE_END
        end
      end

      context "when :comment is true" do
        def call(lines) = make(lines).scanlines(0, 0, comment: true)

        it "does not ignore leading comments" do
          l = ["", "# comment", "b"]
          expect(call l).to eq [1, 0]
        end

        it "does not ignore embedded comments in otherwise blank lines" do
          l = ["", "  # comment", "b"]
          expect(call l).to eq [1, 0]
        end
      end
    end

#   context "it recognizes" do
#     it "keywords"
#     it "
#   end
  end
end

