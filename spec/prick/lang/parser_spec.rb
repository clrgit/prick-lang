
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
      ast = make(lines.align).parse
      capture { ast.dump }.sub(/^Program\n\s*Block\n/m, "").align
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

        context "require statements" do
          it "with one argument" do
            l = %(
              require a
            )
            expect(dump l).to eq %(
              Require a
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
              if env test
                a.sql
                b.sql
              end
            )
            expect(dump l).to eq %(
              If env(test)
                Block
                  File a.sql
                  File b.sql
            ).align
          end

          it "with a else clause" do
            l = %(
              if env test
                a.sql
                b.sql
              else
                c.sql
              end
            )
            expect(dump l).to eq %(
              If env(test)
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
              if env test1
                a.sql
                b.sql
              elsif env test2
                c.sql
              else
                d.sql
              end
            )
            expect(dump l).to eq %(
              If env(test1)
                Block
                  File a.sql
                  File b.sql
              Elsif env(test2)
                Block
                  File c.sql
              Else
                Block
                  File d.sql
            ).align
          end
        end

        context "case statements" do
          it "with single when-values" do
            l = %(
              case env
                when test
                  a.sql
              end
            )
            expect(dump l).to eq %(
              Case env
                When test
                  Block
                    File a.sql
            ).align
          end
        end

        context "runtime expressions" do
          it "with a single argument" do
            l = %(
              if env test
                a.sql
              end
            )
            expect(dump l).to eq %(
              If env(test)
                Block
                  File a.sql
            ).align
          end
          it "with multiple arguments" do
            l = %(
              if env test1 test2
                a.sql
              end
            )
            expect(dump l).to eq %(
              If env(test1, test2)
                Block
                  File a.sql
            ).align
          end
        end

        context "reference expressions" do
          it "with an ident argument" do
            l = %(
              if schema schema1
                a.sql
              end
            )
            expect(dump l).to eq %(
              If schema(schema1)
                Block
                  File a.sql
            ).align
          end
          it "with a object reference argument" do
            l = %(
              if object a.b.c
                a.sql
              end
            )
            expect(dump l).to eq %(
              If object(a.b.c)
                Block
                  File a.sql
            ).align
          end
          it "with a group reference argument" do
            l = %(
              if group a::b::c
                a.sql
              end
            )
            expect(dump l).to eq %(
              If group(a::b::c)
                Block
                  File a.sql
            ).align
          end
        end

        context "unary expressions" do
          it "with one argument" do
            l = %(
              if ! env test
                a.sql
              end
            )
            expect(dump l).to eq %(
              If !(env(test))
                Block
                  File a.sql
            ).align
          end
          it "associates operators" do
            l = %(
              if ! env test && env prod
                a.sql
              end
            )
            expect(dump l).to eq %(
              If &&(!(env(test)), env(prod))
                Block
                  File a.sql
            ).align
          end
        end

        context "binary expressions" do
          it "with two arguments" do
            l = %(
              if env test || env import
                a.sql
              end
            )
            expect(dump l).to eq %(
              If ||(env(test), env(import))
                Block
                  File a.sql
            ).align
          end
          it "with multi-argument runtime expressions" do
            l = %(
              if env test1 test2 || env import1 import2
                a.sql
              end
            )
            expect(dump l).to eq %(
              If ||(env(test1, test2), env(import1, import2))
                Block
                  File a.sql
            ).align
          end
          it "associates operators" do
            l = %(
              if env test || env import && env app
                a.sql
              end
            )
            expect(dump l).to eq %(
              If ||(env(test), &&(env(import), env(app)))
                Block
                  File a.sql
            ).align
          end
        end

        context "parenthesized expressions" do
          it "with one argument" do
            l = %(
              if ( env test )
                a.sql
              end
            )
            expect(dump l).to eq %(
              If env(test)
                Block
                  File a.sql
            ).align
          end
        end

      end
    end
  end
end

