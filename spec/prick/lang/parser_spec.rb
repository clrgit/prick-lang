
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

    def capture(stream = :stdout) # ChatGPT
      begin
        stream = stream.to_s
        old = eval("$#{stream}")
        eval("$#{stream} = StringIO.new")
        yield
        eval("$#{stream}").string
      ensure
        eval("$#{stream} = old")
      end
    end

    def dump(lines)
      capture { call(lines).dump }.sub(/^Program\n/m, "").align
    end

    describe "#parse" do
      it "returns an Ast::Program node" do
        lines = %(file.sql)
        expect(call lines).to be_a Prick::Lang::Ast::Program
      end
    end
  end
end

__END__

      context "it parses" do
        def sig(lines) = call(lines).children.first.dumpsig
        def sigs(lines) = call(lines).children.map(&:dumpsig)
        def blocksig(lines) = call(lines).children.first.children.first.children.map { |c| c.dumpsig }

        context "phase blocks" do
          it "with a file argument" do
            lines = %(init file.sql)
            expect(blocksig lines).to eq ["File file.sql"]
          end
          it "with a command argument" do
            lines = %(init exec ls -l)
            expect(blocksig lines).to eq ["Exec ls -l"]
          end
          it "with a command with a text block argument" do
            lines = %(
              init exec |
                ls -l
                echo
            )
            expect(blocksig lines).to eq ["Exec ls -l; echo"]
          end
          it "with a block" do
            lines = %(
              init {
                a.sql
                b.sql
              }
            )
            expect(blocksig lines).to eq ["File a.sql", "File b.sql"]
          end
        end

        context "file statements" do
          it "with a single argument" do
            lines = %(file.sql)
            expect(sig lines).to eq "File file.sql"
          end
          it "with multiple arguments" do
            lines = %(a.sql b.sql c.sql)
            expect(sigs lines).to eq ["File a.sql", "File b.sql", "File c.sql"]
          end
        end

        def d(t, s) = puts "#{t} #{s}: #{s.encoding}"

        context "commands" do
          it "with a LINE argument" do
            lines = %(eval ls -l)
            expect(sig lines).to eq "Eval ls -l"
          end
          it "with a TEXT argument" do
            lines = %(
              eval |
                ls -l
                echo
            )
            expect(sig lines).to eq "Eval ls -l; echo"
          end
        end

        context "if statements" do
          it "with only a then clause" do
            lines = %(
              if expr
                a.sql
                b.sql
              end
            )

            expect(dump lines).to eq %(
              If expr
                Block
                  File a.sql
                  File b.sql
            ).align
          end

          it "with a else clause" do
            lines = %(
              if expr
                a.sql
                b.sql
              else
                c.sql
              end
            )
            expect(dump lines).to eq %(
              If expr
                Block
                  File a.sql
                  File b.sql
              Else
                Block
                  File c.sql
            ).align
          end

          it "with multiple elsif clauses" do
            lines = %(
              if expr1
                a.sql
                b.sql
              elsif expr2
                c.sql
              else
                d.sql
              end
            )
            expect(dump lines).to eq %(
              If expr1
                Block
                  File a.sql
                  File b.sql
              Elsif expr2
                Block
                  File c.sql
              Else
                Block
                  File d.sql
            ).align
          end
        end
      end
    end
  end
end

#   def dump(lines)
#     old_stdout = $stdout
#     $stdout = StringIO.new
#     call lines
#     $stdout.string.sub(/^.*?\n/m, "").align
#   ensure
#     $stdout = old_stdout
#   end

#   def capture(&block)
#     old_stdout = $stdout
#     $stdout = StringIO.new
#     yield
#     $stdout.string.sub(/^.*?\n/m, "").align
#   ensure
#     $stdout = old_stdout
#   end


