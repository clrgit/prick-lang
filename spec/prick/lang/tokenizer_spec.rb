
using String::Text

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
