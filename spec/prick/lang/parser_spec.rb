describe "Prick::Lang" do
  using String::Text

  describe "Parser" do
    def file = "file.txt" # Considered a constant

    def make(lines)
      lines = lines.split "\n", -1
#     allow(IO).to receive(:readlines).with('file.txt').and_return(lines)
      c = Prick::Lang::Compiler.new(file)
      t = Prick::Lang::Tokenizer.new(c, lines)
      Prick::Lang::Parser.new(t)
    end

    def call(lines)
      make(lines).parse
    end

    describe "#parse" do
      it "returns an Ast::Program node" do
        lines = %(file.sql)
        expect(call lines).to be_a Prick::Lang::Ast::Program
      end

      context "it parses" do
        def sig(lines) = call(lines).children.first.sig
        def sigs(lines) = call(lines).children.map(&:sig)
        def blocksig(lines) = call(lines).children.first.children.first.children.map { |c| c.sig }

        context "phase blocks" do
          it "with a file argument" do
            lines = %(init file.sql)
            expect(blocksig lines).to eq ["FILE file.sql"]
          end
          it "with a command argument" do
            lines = %(init exec ls -l)
            expect(blocksig lines).to eq ["EXEC ls -l"]
          end
          it "with a command with a text block argument" do
            lines = %(
              init exec |
                ls -l
                echo
            )
            expect(blocksig lines).to eq ["EXEC ls -l; echo"]
          end
          it "with a block" do
            lines = %(
              init {
                a.sql
                b.sql
              }
            )
            expect(blocksig lines).to eq ["FILE a.sql", "FILE b.sql"]
          end
        end

        context "file statements" do
          it "with a single argument" do
            lines = %(file.sql)
            expect(sig lines).to eq "FILE file.sql"
          end
          it "with multiple arguments" do
            lines = %(a.sql b.sql c.sql)
            expect(sigs lines).to eq ["FILE a.sql", "FILE b.sql", "FILE c.sql"]
          end
        end

        context "commands" do
          it "with a LINE argument" do
            lines = %(eval ls -l)
            expect(sig lines).to eq "EVAL ls -l"
          end
          it "with a TEXT argument" do
            lines = %(
              eval |
                ls -l
                echo
            )
            expect(sig lines).to eq "EVAL ls -l; echo"
          end
        end

        context "if statements" do
          it "with only a then clause" do
            lines = %(
              if expr
                a.sql
                b.sql
              else
                c.sql
              end
            )
            call(lines).dump
            p sig(lines)
          end
        end
      end
    end
  end
end


