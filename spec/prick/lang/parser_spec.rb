
require './lib/prick/lang/ast.sig.rb'

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
      tk = Prick::Lang::Tokenizer.new(file, lines)
      pa = Prick::Lang::Parser.new(tk)
    end

    def call(lines)
      make(lines).parse
    end

    def sig(lines)
      ast = make(lines.align).parse
      capture { ast.sig }.sub(/^Program\s*\n\s*Block\n/m, "").align
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
            expect(sig l).to eq "File file.sql"
          end
          it "with multiple files" do
            l = %(a.sql b.sql)
            expect(sig l).to eq %(
              File a.sql
              File b.sql
            ).align
          end
        end

        context "schema declarations" do
          it "with a name argument" do
            l = %(
              schema app {
                file.sql
              }
            )
            expect(sig l).to eq %(
              Schema app
                Block
                  File file.sql
            ).align
          end
        end

        context "function declarations" do
          it "with a name argument" do
            l = %(
              function func {
                file.sql
              }
            )
            expect(sig l).to eq %(
              Function func
                Block
                  File file.sql
            ).align
          end
        end

        context "provide statements" do
          it "with one argument" do
            l = %(
              provide a
            )
            expect(sig l).to eq %(
              Provide a
            ).align
          end
        end

        context "require statements" do
          it "with one argument" do
            l = %(
              require a
            )
            expect(sig l).to eq %(
              Require a
            ).align
          end
          it "with multiple arguments" do
            l = %(
              require a b
            )
            expect(sig l).to eq %(
              Require a, b
            ).align
          end
        end

        context "phase blocks" do
          it "with a file argument" do
            l = %(init file.sql)
            expect(sig l).to eq %(
              Phase init
                Block
                  File file.sql
            ).align
          end
          it "with a command argument" do
            l = %(init exec ls -l)
            expect(sig l).to eq %(
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
            expect(sig l).to eq %(
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
            expect(sig l).to eq %(
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
            expect(sig l).to eq %(
              If ENV(test)
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
            expect(sig l).to eq %(
              If ENV(test)
                Block
                  File a.sql
                  File b.sql
              Else
                Block
                  File c.sql
            ).align
          end

          it "with elsif clauses" do
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
            expect(sig l).to eq %(
              If ENV(test1)
                Block
                  File a.sql
                  File b.sql
              Elsif ENV(test2)
                Block
                  File c.sql
              Else
                Block
                  File d.sql
            ).align
          end

          it "with a version expression" do
            l = %(
              if version >= 1.2.3
                a.sql
              end
            )
            expect(sig l).to eq %(
              If VERSION >=(1.2.3)
                Block
                  File a.sql
            ).align
          end

          it "with multiple version expressions" do
            l = %(
              if version >=1.2.3 <4.5.6
                a.sql
              end
            )
            expect(sig l).to eq %(
              If VERSION >=(1.2.3) <(4.5.6)
                Block
                  File a.sql
            ).align
          end
        end

        context "case statements" do
          it "with single reference when-values" do
            l = %(
              case env
                when test
                  a.sql
              end
            )
            expect(sig l).to eq %(
              Case ENV
                When Reference("test")
                  Block
                    File a.sql
            ).align
          end

          it "with single version when-values" do
            l = %(
              case version
                when 1.2.3
                  a.sql
              end
            )
            expect(sig l).to eq %(
              Case VERSION
                When ==(1.2.3)
                  Block
                    File a.sql
            ).align
          end

          it "with single version expression when-values" do
            l = %(
              case version
                when >=1.2.3
                  a.sql
              end
            )
            expect(sig l).to eq %(
              Case VERSION
                When >=(1.2.3)
                  Block
                    File a.sql
            ).align
          end

          it "with multiple reference when-values" do
            l = %(
              case env
                when test prod
                  a.sql
              end
            )
            expect(sig l).to eq %(
              Case ENV
                When Reference("test"), Reference("prod")
                  Block
                    File a.sql
            ).align
          end

          it "with multiple version when-values" do
            l = %(
              case version
                when ~>1.2.3 <4.5.6
                  a.sql
              end
            )
            expect(sig l).to eq %(
              Case VERSION
                When ~>(1.2.3), <(4.5.6)
                  Block
                    File a.sql
            ).align
          end

          it "fails on commas in list (with a sensible error message)" # do
#           l = %(
#             case env
#               when test, prod
#                 a.sql
#             end
#           )
#           expect(sig l).to eq %(
#             Case env
#               When Reference("test"), Reference("prod")
#                 Block
#                   File a.sql
#           ).align
#         end
        end

        context "source commands" do
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

        context "call commands" do
          it "with a single reference argument" do
            l = %(call func)
            expect(sig l).to eq "Call func"
          end
          it "with multiple name arguments" do
            l = %(call func1 func2)
            expect(sig l).to eq "Call func1, func2"
          end
        end

        context "expressions" do
          it "does not extend to next line" do
            l = %(
              if env prod
                schema a {
                  a.sql
                }
              end
            )
            expect { sig l }.not_to raise_exception
          end
        end

        context "runtime expressions" do
          it "with a single argument" do
            l = %(
              if env test
                a.sql
              end
            )
            expect(sig l).to eq %(
              If ENV(test)
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
            expect(sig l).to eq %(
              If ENV(test1, test2)
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
            expect(sig l).to eq %(
              If SCHEMA(schema1)
                Block
                  File a.sql
            ).align
          end
          it "with a object reference argument" do
            l = %(
              if object a.b
                a.sql
              end
            )
            expect(sig l).to eq %(
              If OBJECT(a.b)
                Block
                  File a.sql
            ).align
          end
          it "with a resource reference argument" do
            l = %(
              if resource a.b
                a.sql
              end
            )
            expect(sig l).to eq %(
              If RESOURCE(a.b)
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
            expect(sig l).to eq %(
              If !(ENV(test))
                Block
                  File a.sql
            ).align
          end
          it "associates operators X" do
            l = %(
              if ! env test && env prod
                a.sql
              end
            )
            expect(sig l).to eq %(
              If &&(!(ENV(test)), ENV(prod))
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
            expect(sig l).to eq %(
              If ||(ENV(test), ENV(import))
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
            expect(sig l).to eq %(
              If ||(ENV(test1, test2), ENV(import1, import2))
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
            expect(sig l).to eq %(
              If ||(ENV(test), &&(ENV(import), ENV(app)))
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
            expect(sig l).to eq %(
              If ENV(test)
                Block
                  File a.sql
            ).align
          end
        end

        context "references" do
          it "ignores keywords"
          it "with a simple identifier" do
            l = %(call func)
            expect(sig l).to eq "Call func"
          end
          it "with an initial dot" do
            l = %(call .func)
            expect(sig l).to eq "Call .func"
          end
          it "with dot-separated identifiers" do
            l = %(call func1.func2)
            expect(sig l).to eq "Call func1.func2"
          end
        end
      end
    end
  end
end

