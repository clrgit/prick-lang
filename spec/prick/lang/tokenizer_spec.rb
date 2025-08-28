
module Prick::Lang
  class Tokenizer
    # Return rest of line
    def rest = @lines[@index][@pos..-1]

    # Set end of line
    def eol!() @pos = line&.size || 0 end

#   public :nextline, :skiplines, :parse_token
  end
end

describe "Prick::Lang" do
  describe "Tokenizer" do
    def file = "file.txt" # Considered a constant

    def make(lines)
#     lines = lines.split "\n", -1
#     allow(IO).to receive(:readlines).with('file.txt').and_return(lines)
      c = Prick::Lang::Compiler.new(file)
      Prick::Lang::Tokenizer.new(c, lines)
    end

    describe "#peek" do
      it "forwards to #read with kind: true" # do
#       l = %w(exec)
#       t = make l
#       expect(t).to receive(:read).with(nil, peek: true)
#       t.peek
#     end
    end

    describe "#read" do
      def call(lines) = make(lines).read
      def kind(lines) = call(lines)&.kind
      def error_token(lines)
        t = make(lines)
        t.read
        t.error
      end

      it "reads keyword tokens" do
        l = ["  exec", "eval"]
        expect(kind l).to eq :EXEC
      end

      it "reads file tokens" do
        l = ["t.sql"]
        expect(kind l).to eq :FILE
      end

      it "skips initial empty lines if :eol is false (the default)" do
        l = ["exec", "eval"]
        t = make l
        t.read
        tk = t.read
        expect(tk.lineno).to eq 2
        expect(tk.charno).to eq 1
        expect(tk.kind).to eq :EVAL
      end
      it "returns a EOL token if at end of line and :eol is true"

      it "moves the position" do
        l = ["exec eval"]
        t = make l
        t.read
        expect(t.lineno).to eq 1
        expect(t.charno).to eq 6
      end

      it "advances to the next line if end of line after match" do
      end

      it "clears peek'ed token" do
        l = ["exec", "eval"]
        t = make l
        tk0 = t.peek
        tk1 = t.read
        tk2 = t.peek
        expect(tk0).to eq tk1
        expect(tk2).not_to eq tk1
      end

      context "when unknown/unexpected token" do
        it "returns nil" do
          l = [".word"]
          t = make l
          expect(t.read).to eq nil
        end

        it "sets #error_token" do
          l = [".word"]
          t = make l
          t.read
          expect(t.error.text).to eq ".word"
        end
      end

#     context "with a kinds argument" do
#       it "restricts the token to that kind" do
#         l = ["exec"]
#         expect(kind :EXEC, l).to eq :EXEC
#       end
#       context "when not the expected kind" do
#         it "returns nil" do
#           l = ["exec"]
#           expect(kind :IF, l).to eq nil
#         end
#         it "sets #error_token" do
#           l = ["exec"]
#           t = make l
#           t.read(:IF)
#           expect(t.error_token.text).to eq "exec"
#         end
#       end
#     end

#     context "when :peek is true" do
#       it "doesn't move the position" do
#         l = ["exec eval"]
#         t = make l
#         t.read(peek: true)
#         expect(t.lineno).to eq 1
#         expect(t.charno).to eq 1
#       end
#       it "returns a previous peek'ed token" do
#         l = ["exec eval"]
#         t = make l
#         tk1 = t.read(peek: true)
#         tk2 = t.read(peek: true)
#         expect(tk1.object_id).to eq tk2.object_id
#       end
#       context "when followed by a read w/o peek" do
#         it "returns a previous peek'ed token" do
#           l = ["exec eval"]
#           t = make l
#           tk1 = t.read(peek: true)
#           tk2 = t.read
#           expect(tk1.object_id).to eq tk2.object_id
#         end
#       end
#     end
    end

    describe "#readline" do
      def call(lines) = make(lines).readline

      it "returns nil if eof?" do
        l = []
        expect(call l).to eq nil
      end

      it "returns nil if eol?" do
        l = %w(exec)
        t = make l
        t.eol!
        expect(t.readline).to eq nil
      end

      it "returns rest of line as a LINE token" do
        l = ["exec a b c"]
        t = make l
        t.read
        expect(t.readline.text).to eq "a b c"
      end

      it "skips initial empty lines even when peeking"

      it "advances to the next line" do
        l = %w(exec eval)
        t = make l
        t.readline
        expect(t.lineno).to eq 2
      end
    end

    describe "#readtext" do
      def call(lines) = make(lines).readtext(2)
      def text(lines) = call(lines).text

      it "returns nil if eof?" do
        l = []
        expect(call l).to eq nil
      end

      it "return nil if eol?" do
        l = %w(a b)
        t = make l
        t.eol!
        expect(call l).to eq nil
      end

#     it "raises if not bol?" do
#       t = make ["a", "b"]
#       t.eol!
#       expect { t.readtext(2) }.to raise_error Prick::Lang::Error, /Not at start of line/
#     end

      it "returns a TEXT token X" do
        l = ["  a", "  b"]
        expect(call(l).kind).to eq :TEXT
      end

      it "sets token file/lineno/charno" do
        l = ["  a", "  b"]
        tk = call l
        expect(tk.file).to eq file
        expect(tk.lineno).to eq 1
        expect(tk.charno).to eq 1
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

      it "aligns to the least indented non-blank line" do
        l = ["", "    a", "", "  b"]
        expect(text l).to eq "  a\n\nb"
      end

      it "advances to the next line" do
        l = ["a", "b"]
        t = make l
        t.readline
        expect(t.lineno).to eq 2
        expect(t.charno).to eq 1
      end
    end

    describe "#skiplines" do
      def call(lines) = make(lines).skiplines
      def line(lines) = make(lines).tap(&:skiplines).line

      it "skips single empty line" do
        l = [""]
        expect(line l).to eq nil
      end

      it "skips multiple empty lines" do
        l = ["", ""]
        expect(line l).to eq nil
      end

      it "returns the first non-empty line" do
        l = ["", "", "a", "", "b"]
        expect(line l).to eq "a"
      end

      it "advances to the first non-empty line" do
        t = make ["", "b"]
        t.skiplines
        expect(t.line).to eq "b"
        expect(t.lineno).to eq 2
        expect(t.charno).to eq 1
      end

      context "when :comment is true (default)" do
        it "ignores leading comments" do
          l = ["# comment", "b"]
          expect(line l).to eq "b"
        end

        it "ignores embedded comments in otherwise blank lines" do
          l = ["  # comment", "b"]
          expect(line l).to eq "b"
        end
      end

      context "when :comment is false" do
        def call(lines) = make(lines).skiplines(comment: false)
        def line(lines) = make(lines).tap { _1.skiplines(comment: false) }.line

        it "does not ignore leading comments" do
          l = ["# comment", "b"]
          expect(line l).to eq "# comment"
        end

        it "does not ignore embedded comments in otherwise blank lines" do
          l = ["  # comment", "b"]
          expect(line l).to eq "  # comment"
        end
      end
    end
  end
end

