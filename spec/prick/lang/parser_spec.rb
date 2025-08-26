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
        p = make %(
          schema app_portal {
            file.sql
            file.psql
            file.rb

            init {
              a.sql
              b.sql
            }

            exec ls -l
            eval |
              ls -l
#             asdf
              echo 'hej
              # inline comment
              sed 's/#/not a comment/'

            back.sql
          }
        )
        expect(ast = p.parse).to be_a Prick::Lang::Ast::Program
#       puts "--------------"
#       ast.dump


      end



      context "it parses" do
        def sig(lines) = call(lines).children.first.sig
        def sigs(lines) = call(lines).children.map(&:sig)

        context "phase blocks" do
          it "with a file argument"
          it "with a command argument"
          it "with a block"
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
          it "with a BLOCK argument" do
            lines = %(
              eval |
                ls -l
                echo
            )
            expect(sig lines).to eq "EVAL ls -l; echo"
          end
        end
      end
    end
  end
end


