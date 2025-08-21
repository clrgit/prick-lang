
describe "Prick::Lang" do
  describe "Tokenizer" do
    def file = "file.txt" # Considered a constant

    def make(lines)
#     lines = lines.split "\n", -1
#     allow(IO).to receive(:readlines).with('file.txt').and_return(lines)
      c = Prick::Lang::Compiler.new(file)
      Prick::Lang::Tokenizer.new(c, lines)
    end

    describe "#skip_blanks" do
      def call(lines) = make(lines).skip_blanks

      it "returns nil if eof" do
        l = []
        expect(call l).to eq nil
      end

      it "raises if not bol?" do
        t = make ["a", "b"]
        t.eol!
        expect { t.skip_blanks }.to raise_error Prick::Lang::Error, /Not at start of line/
      end

      it "returns nil on single blank line" do
        l = [""]
        expect(call l).to eq nil
      end

      it "returns nil on multiple blank lines" do
        l = ["", ""]
        expect(call l).to eq nil
      end

      it "returns the first non-blank line" do
        l = ["a", "", "b"]
        expect(call l).to eq "a"
      end

      it "advances to the first non-blank line" do
        t = make ["", "b"]
        expect(t.skip_blanks).to eq "b"
        expect(t.lineno).to eq 2
        expect(t.charno).to eq 1
      end

      it "skips initial blank line" do
        l = ["", "b"]
        expect(call l).to eq "b"
      end
      it "skips initial blank lines" do
        l = ["", "", "b"]
        expect(call l).to eq "b"
      end

      it "ignores leading comments" do
        l = ["# comment", "b"]
        expect(call l).to eq "b"
      end
      it "ignores embedded comments comments in otherwise blank lines" do
        l = ["  # comment", "b"]
        expect(call l).to eq "b"
      end
    end

    describe "#readline" do
      def call(lines) = make(lines).readline

      it "returns nil if eof?" do
        l = []
        expect(call l).to eq nil
      end

      it "raises if not bol?" do
        t = make ["a", "b"]
        t.eol!
        expect { t.readline }.to raise_error Prick::Lang::Error, /Not at start of line/
      end

      it "returns a LINE token" do
        l = ["a", "b"]
        expect(call(l).kind).to eq :LINE
      end

      it "sets token file/lineno/charno" do
        l = ["a", "b"]
        tk = call l
        expect(tk.file).to eq file
        expect(tk.lineno).to eq 1
        expect(tk.charno).to eq 1
      end

      it "advances to the next line" do
        l = ["a", "b"]
        t = make l
        t.readline
        expect(t.lineno).to eq 2
        expect(t.charno).to eq 1
      end
    end

#   describe "#readblock" do
#     def call(lines) = make(lines).readblock
#
#     it "returns nil if eof?" do
#       l = []
#       expect(call l).to eq nil
#     end
#
#     it "raises if not bol?" do
#       t = make ["a", "b"]
#       t.eol!
#       expect { t.readblock }.to raise_error Prick::Lang::Error, /Not at start of line/
#     end
#
#     it "returns a LINE token" do
#       l = ["a", "b"]
#       expect(call(l).kind).to eq :BLOCK
#     end
#
#     it "sets token file/lineno/charno" do
#       l = ["a", "b"]
#       tk = call l
#       expect(tk.file).to eq file
#       expect(tk.lineno).to eq 1
#       expect(tk.charno).to eq 1
#     end
#
#     it "advances to the next line" do
#       l = ["a", "b"]
#       t = make l
#       t.readline
#       expect(t.lineno).to eq 2
#       expect(t.charno).to eq 1
#     end
#   end
  end
end


#    lines = ["a\n", "\n", "b\n"]
#     it "ignores singleton blank line"
#     it "stops at the first non-blank lines"


__END__


#module Prick::Lang
# class Tokenizer
#   # Read all lines. Used for testing
#   def readlines(raw: true)
#     r = []
#     while l = readline(raw: raw)
#       r << l
#     end
#     r
#   end
# end
#end

#describe "Prick::Lang" do
# describe "LineTokenizer" do
#   def make(line)
#     Prick::Lang::LineTokenizer.new(nil, 0, line)
#   end
#
#   describe "#source" do
#     it "returns the source of the line" do
#       s = "  asdf # qwer"
#       expect(make(s).source).to eq s
#     end
#   end
#   describe "#line" do
#     it "exclude comments" do
#       s = "asdf # qwer"
#       expect(make(s).line).to eq "asdf"
#     end
#     it "exclude trailing whitespace" do
#       s = "asdf  "
#       expect(make(s).line).to eq "asdf"
#     end
#     it "exclude leading whitespace" do
#       s = "  asdf"
#       expect(make(s).line).to eq "asdf"
#     end
#   end
#   describe "#peekword" do
#     def call(line) make(line).peekword end
#     context "returns" do
#       it "nil if empty" do
#         expect(call "").to eq nil
#       end
#       it "{ or } if present" do
#         expect(call "  { asdf").to eq "{"
#       end
#       it "a word if present" do
#         expect(call "  asdf {").to eq "asdf"
#       end
#       it "otherwise the rest of the line" do
#         expect(call "  .asdf/qwer zxcv  ").to eq ".asdf/qwer zxcv"
#       end
#     end
#   end
#   describe "#readword" do
#     it "extracts and returns the next word" do
#       s = "  1 2 3  "
#       l = make(s)
#       expect(l.readword).to eq "1"
#       expect(l.readword).to eq "2"
#     end
#     it "returns nil when if at end of line" do
#       s = "  1  "
#       l = make(s)
#       l.readword
#       expect(l.readword).to eq nil
#     end
#   end
#
#   describe "#readtoken" do
#     def kind(lines) = make(lines).readtoken.kind
#     def text(lines) = make(lines).readtoken.text
#
#     it "returns a Token object"
#
#     it "returns global variable tokens" do
#       s = "schema NAME"
#       expect(kind(s)).to eq :SCHEMA
#     end
#     it "returns control tokens" do
#       s = "if env = :seeds"
#       expect(kind(s)).to eq :IF
#     end
#     it "returns block tokens" do
#       s = "init something.sql"
#       expect(kind(s)).to eq :INIT
#     end
#     it "returns command tokens" do
#       s = "exec something.sql"
#       expect(kind(s)).to eq :EXEC
#     end
#     it "returns punctuation tokens" do
#       s = "{ something.sql }"
#       expect(kind(s)).to eq :BRACE_BEGIN
#     end
#     it "returns text tokens" do
#       s = "command args"
#       expect(kind(s)).to eq :TEXT
#     end
#   end
#
#   describe "#indent" do
#     it "returns the number of leading whitespace characters" do
#       s = "  ."
#       expect(make(s).indent).to eq 2
#     end
#     it "returns 0 if the line is empty" do
#       s = ""
#       expect(make(s).indent).to eq 0
#     end
#   end
#
#   describe "#empty?" do
#     it "returns true if line is empty" do
#       s = "  # asdf"
#       l = make(s)
#       expect(make(s).empty?).to eq true
#     end
#   end
#
#   describe "#eol?" do
#     it "returns true iff at end of line" do
#       s = "  1  "
#       l = make(s)
#       expect(l.eol?).to eq false
#       l.readword
#       expect(l.eol?).to eq true
#     end
#   end
#
# end
#end

describe "Prick::Lang" do
  describe "Tokenizer" do
    def make(lines)
      lines = lines.split "\n", -1
      allow(IO).to receive(:readlines).with('file.txt').and_return(lines)
      c = Prick::Lang::Compiler.new('file.txt')
      Prick::Lang::Tokenizer.new(c)
    end

    describe "#indent" do
      it "is zero-based" do
        lines = "text"
        expect(make(lines).indent).to eq 0
      end
      it "returns the indent of the line" do
        lines = "  text"
        expect(make(lines).indent).to eq 2
      end
      it "returns nil if the line is empty" do
        lines = "\n\n"
        t = make(lines)
        expect(t.indent).to eq nil
      end
    end

    describe "#peekword" do
      def word(text)
        t = make(text)
        t.peekword
      end
      it "accepts a word" do
        expect(word "  if text").to eq "if"
      end
      it "accepts punctuation" do
        expect(word "{ text").to eq "{"
      end
      it "accepts a single character" do
        expect(word "@ampersand text").to eq "@"
      end
      it "sets indent" do
        expect(make("  word text").indent).to eq 2
      end
    end

    describe "#peektext" do
      def call(text)
        t = make(text)
        t.peektext
      end

      it "returns the rest of the line" do
        expect(call "if something").to eq "if something"
      end
    end

    describe "#peekline" do
      def call(text)
        t = make(text)
        t.peekline
      end

      it "returns a full line" do
        expect(call "  if something").to eq "if something"
      end
    end

    describe "#peekcharno" do
      it "returns the character position of word/line" do
        expect(make("  word").peekcharno).to eq 3
      end
    end

    describe "#peektoken" do
      def kind(text) make(text).peektoken.kind end
      def text(text) make(text).peektoken.text end
      def filename(text) make(text).peektoken.filename end
      def extname(text) make(text).peektoken.extname end

      context "when token matches" do
        context "a keyword" do
          def src = "if statement"
          it "sets kind to the token" do
            expect(kind src).to eq :IF
          end
          it "sets text to the matched string" do
            expect(text src).to eq "if"
          end
        end
        context "punctuation" do
          def src = "{ statement"
          it "sets kind to the token" do
            expect(kind src).to eq :BRACE_BEGIN
          end
          it "sets text to the matched string" do
            expect(text src).to eq "{"
          end
        end
        context "file names" do
          def src = "file.sql"
          it "sets kind to FILE" do
            expect(kind src).to eq :FILE
          end
          it "sets text to the filename" do
            expect(text src).to eq "file.sql"
          end
          it "sets filename to the basename of the file" do
            expect(filename src).to eq "file"
          end
          it "sets extname to the extension of the file" do
            expect(extname src).to eq "sql"
          end
        end
        context "otherwise" do
          def src = "something else"
          it "sets kind to TEXT" do
            expect(kind src).to eq :TEXT
          end
          it "sets text to the rest of the line" do
            expect(text src).to eq "something else"
          end
        end
        context "when kind is" do
          context ":TEXT" do
            it "returns a TEXT token"
          end
          context ":LINE" do
            it "returns a LINE token"
          end
          context "given" do
            it "returns a token of the given kind"
          end
          context "when the token was previously peek'ed with a different kind" do
            it "fails"
          end
        end


      end
#     contee
#     context "it matches" do
#       it "keyword" do
#         expect(kind "if something").to eq :IF
#       end
#       it "punctuation" do
#         expect(kind "{ something").to eq :BRACE_BEGIN
#       end
#       it "text" do
#         expect(kind "word word").to eq :TEXT
#       end
#     end
#     context "it sets
    end
  end
end

__END__


      context "it recognizes" do

        it "keywords" do
          expect(call "if").to eq :IF
        end
        it "punctuation" do
          expect(call "{").to eq :BRACE_BEGIN
        end
        it "sql files" do
          expect(call "f.sql").to eq :FILE
        end
        it "psql files" do
          expect(call "f.psql").to eq :FILE
        end
        it "ruby files" do
          expect(call "f.rb").to eq :FILE
        end
        it "fox files" do
          expect(call "f.fox").to eq :FILE
        end
        it "prick files" do
          expect(call "f.prick").to eq :FILE
        end
        it "text" do
          expect(call "txt").to eq :TEXT
          expect(call "f.txt").to eq :TEXT
          expect(call ".f.sql").to eq :TEXT
        end
      end
    end

#   describe "#peekline" do
#     it "returns a LineTokenizer object" do
#       lines = "hej\n"
#       t = make(lines)
#       expect(t.peekline).to be_a Prick::Lang::LineTokenizer
#     end
#     it "returns the next line to be read" do
#       lines = "hej\ndu\n"
#     end
#     it "returns nil if at end of file"
#   end

    describe "#readline" do
#     it "returns a LineTokenizer object" do
#       lines = "hej\n"
#       t = make(lines)
#       expect(t.readline).to be_a Prick::Lang::LineTokenizer
#     end

      it "reads the lines" do
        lines = "hej\ndu\n"
        t = make(lines)
        expect(t.readline).to eq "hej"
        expect(t.readline).to eq "du"
      end

      it "ignores empty lines" do
        lines = "\nhej\n\ndu\n"
        t = make(lines)
        expect(t.readline).to eq "hej"
        expect(t.readline).to eq "du"
      end

      it "returns nil on eof" do
        lines = "hej\n"
        t = make(lines)
        t.readline
        expect(t.readline).to eq nil
      end
    end
  end
end

__END__

module Prick::Lang
  class Tokenizer
    # Read all lines (used for debug)
    def readlines
      l = []
      while readline
        l << line
      end
      l
    end
  end
end

describe "Prick::Lang" do
  describe "Tokenizer" do
    def tokenizer(lines)
      lines = lines.split "\n"
      allow(IO).to receive(:readlines).with('file.txt').and_return(lines)
      c = Prick::Lang::Compiler.new('file.txt')
      Prick::Lang::Tokenizer.new(c)
    end

    describe "#readline" do
      it "reads lines from a file" do
        lines = "hej\nmed\ndig\n"
        t = tokenizer(lines)
        expect(t.readlines.size).to eq 3
      end

      it "ignores blank lines" do
        lines = %(

          hej

            med
          dig

        )
        t = tokenizer(lines)
        expect(t.readlines.size).to eq 3
      end

      it "ignores comment lines" do
        lines = %(
          # A comment
          hej
            # Another comment
            med
          dig
        )
        t = tokenizer(lines)
        expect(t.readlines.size).to eq 3
      end

      it "ignores line ending comments" do
        lines = %(
          hej # A comment
            med # Another comment
          dig
        ).align
        t = tokenizer(lines)
        expect(t.readlines).to eq ["hej", "  med", "dig"]
      end

      it "ignores line ending spaces" do
        lines = "hej  \n  med   \ndig   "
        t = tokenizer(lines)
        expect(t.readlines).to eq ["hej", "  med", "dig"]
      end

      it "stops reading when __END__ is found" do
        lines = %(
          hej
            med
          __END__
          dig
        ).align
        t = tokenizer(lines)
        expect(t.readlines.size).to eq 2
      end

      it "sets #lineno" do
        lines = "hej\n\nmed\ndig\n"
        t = tokenizer(lines)
        a = []
        while t.readline
          a << t.lineno
        end
        expect(a).to eq [1, 3, 4]
      end

      it "sets #charno to 1" do
        lines = "hej\n\nmed\ndig\n"
        t = tokenizer(lines)
        while t.readline
          expect(t.charno).to eq 1
        end
      end

      it "sets #level" do
        lines = "hej\n  med\ndig\n"
        t = tokenizer(lines)
        a = []
        while t.readline
          a << t.level
        end
        expect(a).to eq [0, 2, 0]
      end

      it "sets #word" do
        lines = "hej\n  med\ndig\n"
        t = tokenizer(lines)
        a = []
        while t.readline
          a << t.word
        end
        expect(a).to eq %w(hej med dig)
      end
    end

    describe "readword" do
      it "reads words" do
        lines = "hej\n\nmed\ndig du gamle\n"
        t = tokenizer(lines)
        a = []
        while w = t.readword
          a << w
        end
        expect(a).to eq %w(hej med dig du gamle)
      end
    end
  end
end

__END__

    it "reads non-blank lines from a file" do
      lines = %(

        hej

          med
        dig

      )
      t = tokenizer(lines)
      expect(t.readlines.size).to eq 3
      while t.readline
        c += 1
      end
      expect(c).to eq 3
    end

    it "sets #level to the indent of the line" do

    end


  end
end
