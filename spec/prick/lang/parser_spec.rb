
describe "Prick::Lang" do
  using String::Text

  describe "Parser" do
    def file = "file.txt" # Considered a constant

    # TODO: Library
    def capture(stream = :stdout, &block) # ChatGPT
      constrain stream, :stdout, :stderr
      begin
        old = eval("$#{stream}")
        eval("$#{stream} = StringIO.new")
        yield
        eval("$#{stream}").string
      ensure
        eval("$#{stream} = old")
      end
    end

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

    def dump(lines)
      ast = make(lines).parse
      capture { ast.dump }.sub(/^Program\n/m, "").align
    end

    describe "#parse" do
      it "returns an Ast::Program node" do
        l = %(file.sql)
        expect(call l).to be_a Prick::Lang::Ast::Program
      end

      context "it parses" do
        context "files" do
          it "with one file" do
            l = %(file.sql)
            expect(dump l).to eq "File file.sql"
          end
          it "with multiple files" do
            l = %(a.sql b.sql)
            expect(dump l).to eq %(
              File a.sql
              File b.sql
            ).align
          end
        end

        context "commands" do
          it "with a LINE argument" do
            l = %(eval ls -l)
            expect(dump l).to eq "Eval ls -l"
          end
          it "with a TEXT argument" do
            l = %(
              eval |
                ls -l
                echo
            )
            expect(dump l).to eq "Eval ls -l; echo"
          end
        end

        context "declarations" do
          it "with a name argument" do
            l = %(
              schema app {
                file.sql
              }
            )
            expect(dump l).to eq %(
              Decl schema "app"
                Block
                  File file.sql
            ).align
          end
        end

        context "phase blocks" do
          it "with a file argument" do
            l = %(init file.sql)
            expect(dump l).to eq %(
              Phase init
                Block
                  File file.sql
            ).align
          end
          it "with a command argument" do
            l = %(init exec ls -l)
            expect(dump l).to eq %(
              Phase init
                Block
                  Exec ls -l
            ).align
          end
          it "with a command with a text block argument" do
            l = %(
              init exec |
                ls -l
                echo
            )
            expect(dump l).to eq %(
              Phase init
                Block
                  Exec ls -l; echo
            ).align
          end
          it "with a block" do
            l = %(
              init {
                a.sql
                b.sql
              }
            )
            expect(dump l).to eq %(
              Phase init
                Block
                  File a.sql
                  File b.sql
            ).align
          end
        end

        context "if statements" do
          it "with only a then clause" do
            l = %(
              if expr
                a.sql
                b.sql
              end
            )
            expect(dump l).to eq %(
              If expr
                Block
                  File a.sql
                  File b.sql
            ).align
          end

          it "with a else clause" do
            l = %(
              if expr
                a.sql
                b.sql
              else
                c.sql
              end
            )
            expect(dump l).to eq %(
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
            l = %(
              if expr1
                a.sql
                b.sql
              elsif expr2
                c.sql
              else
                d.sql
              end
            )
            expect(dump l).to eq %(
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

__END__

      context "it parses" do
        def sig(l) = call(l).children.first.dumpsig
        def sigs(l) = call(l).children.map(&:dumpsig)
        def blocksig(l) = call(l).children.first.children.first.children.map { |c| c.dumpsig }

        context "file statements" do
          it "with a single argument" do
            l = %(file.sql)
            expect(sig l).to eq "File file.sql"
          end
          it "with multiple arguments" do
            l = %(a.sql b.sql c.sql)
            expect(sigs l).to eq ["File a.sql", "File b.sql", "File c.sql"]
          end
        end

        def d(t, s) = puts "#{t} #{s}: #{s.encoding}"

        context "commands" do
          it "with a LINE argument" do
            l = %(eval ls -l)
            expect(sig l).to eq "Eval ls -l"
          end
          it "with a TEXT argument" do
            l = %(
              eval |
                ls -l
                echo
            )
            expect(sig l).to eq "Eval ls -l; echo"
          end
        end

        context "if statements" do
          it "with only a then clause" do
            l = %(
              if expr
                a.sql
                b.sql
              end
            )

            expect(dump l).to eq %(
              If expr
                Block
                  File a.sql
                  File b.sql
            ).align
          end

          it "with a else clause" do
            l = %(
              if expr
                a.sql
                b.sql
              else
                c.sql
              end
            )
            expect(dump l).to eq %(
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
            l = %(
              if expr1
                a.sql
                b.sql
              elsif expr2
                c.sql
              else
                d.sql
              end
            )
            expect(dump l).to eq %(
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

#   def dump(l)
#     old_stdout = $stdout
#     $stdout = StringIO.new
#     call l
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


