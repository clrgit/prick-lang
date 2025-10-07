
describe "Prick::Lang" do
  using String::Text

  describe "Parser" do
    def file = "file.txt" # Considered a constant

#   # TODO: Library
#   def capture(stream = :stdout, &block) # ChatGPT
#     constrain stream, :stdout, :stderr
#     begin
#       old = eval("$#{stream}")
#       eval("$#{stream} = StringIO.new")
#       yield
#       eval("$#{stream}").string
#     ensure
#       eval("$#{stream} = old")
#     end
#   end

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
#     capture { ast.sig }.sub(/^Program\s*\n\s*Block\n/m, "").align
      capture { ast.sig }.align
    end

    def esig(expr) # Expression SIGnature
      lines = %(
        if #{expr}
          t.sql
        end
      )
      sig(lines).sub(/If ([^\n]+)\s*\n.*/m, '\1')
    end

    describe "#parse" do
      it "returns an Ast::Program node" do
        l = %(file.sql)
        expect(call l).to be_a Prick::Lang::Ast::Program
      end

      it "accepts empty input X" do
        l = %()
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
              Require Reference(a)
            ).align
          end
          it "with multiple arguments" do
            l = %(
              require a b
            )
            expect(sig l).to eq %(
              Require Reference(a), Reference(b)
            ).align
          end
        end

        context "phase blocks" do
          it "with a file argument" do
            l = %(init file.sql)
            expect(sig l).to eq %(
              Phase init
                File file.sql
            ).align
          end
          it "with a command argument" do
            l = %(init exec ls -l)
            expect(sig l).to eq %(
              Phase init
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
                File a.sql
                File b.sql
            ).align
          end
        end

        context "if statements" do
          it "with only a then clause" do
            l = %(
              if $env == test
                a.sql
                b.sql
              end
            )

            expect(sig l).to eq %(
              If ==($env, test)
                File a.sql
                File b.sql
            ).align
          end

          it "with a else clause" do
            l = %(
              if $env == test
                a.sql
                b.sql
              else
                c.sql
              end
            )
            expect(sig l).to eq %(
              If ==($env, test)
                File a.sql
                File b.sql
              Else
                File c.sql
            ).align
          end

          it "with elsif clauses" do
            l = %(
              if $env == test1
                a.sql
                b.sql
              elsif $env == test2
                c.sql
              else
                d.sql
              end
            )
            expect(sig l).to eq %(
              If ==($env, test1)
                File a.sql
                File b.sql
              Elsif ==($env, test2)
                File c.sql
              Else
                File d.sql
            ).align
          end
        end

        context "case statements" do
          context "when clauses" do
            it "accepts single value" do
              l = %(
                case $env
                  when test
                    a.sql
                end
              )
              expect(sig l).to eq %(
                Case $env
                  When ==(_, test)
                    File a.sql
              ).align
            end

            it "accepts operator and value" do
              l = %(
                case $version
                  when >= 1.2.3
                    a.sql
                end
              )
              expect(sig l).to eq %(
                Case $version
                  When >=(_, 1.2.3)
                    File a.sql
              ).align
            end

            it "accepts a list of single-values" do
              l = %(
                case $env
                  when test, prod
                    a.sql
                end
              )
              expect(sig l).to eq %(
                Case $env
                  When ==(_, test), ==(_, prod)
                    File a.sql
              ).align
            end
            it "accepts a list of operators and values" do
              l = %(
                case $version
                  when >= 1.2.3, 4.5.6
                    a.sql
                end
              )
              expect(sig l).to eq %(
                Case $version
                  When >=(_, 1.2.3), ==(_, 4.5.6)
                    File a.sql
              ).align
            end
          end
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
            expect(sig l).to eq "Call Reference(func)"
          end
          it "with multiple name arguments" do
            l = %(call func1 func2)
            expect(sig l).to eq "Call Reference(func1), Reference(func2)"
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

        context "unary expressions" do
          it "handles prefix operators" do
            expect(esig("!$env")).to eq "!($env)"
          end
          it "handles suffix operators" do
            expect(esig("env?")).to eq "?(Reference(env))"
          end
          it "handles priorities" do
            expect(esig("!$env?")).to eq "!(?($env))"
          end
        end

        context "binary expressions" do
          it "handles binary expressions" do
            expect(esig("$env == test")).to eq "==($env, test)"
          end
          it "handles priorities" do
            expect(esig("$env == test && $env == prod")).to eq "&&(==($env, test), ==($env, prod))"
          end
          it "handles association" do
            l = %(
              if $env == test || $env == import && $env == app
                a.sql
              end
            )
            expect(sig l).to eq %(
              If ||(==($env, test), &&(==($env, import), ==($env, app)))
                File a.sql
            ).align
          end
        end

        context "parenthesized expressions" do
          it "accepts an expression" do
            l = %(
              if ( $env == test )
                a.sql
              end
            )
            expect(sig l).to eq %(
              If ==($env, test)
                File a.sql
            ).align
          end
          it "handles priorities" do
            e = "($env == test || $env == prod ) && $ver > 1.2.3"
            expect(esig e).to eq "&&(||(==($env, test), ==($env, prod)), >($ver, 1.2.3))"
          end
        end

        context "identifiers" do
          it "accepts identifiers" do
          end
        end

        context "references" do
          it "accepts a single identifier" do
            expect(esig("env?")).to eq "?(Reference(env))"
          end
          it "accepts qualified identifiers" do
            l = %(call a.b)
            expect(sig l).to eq %(
              Call Reference(a.b)
            ).align
          end
          it "accepts an initial dot" do
            l = %(call .b)
            expect(sig l).to eq %(
              Call Reference(.b)
            ).align
          end
        end

        context "version numbers" do
          it "accepts a single-digit version number" do
            e = "$ver == 1"
            expect(esig(e)).to eq "==($ver, 1)"
          end
          it "accepts a double-digit version number" do
            e = "$ver == 1.2"
            expect(esig(e)).to eq "==($ver, 1.2)"
          end
          it "accepts a triple-digit version number" do
            e = "$ver == 1.2.3"
            expect(esig(e)).to eq "==($ver, 1.2.3)"
          end
        end

        context "words" do
          it "accepts literal strings" do
            e = "$env == a_string"
            expect(esig(e)).to eq "==($env, a_string)"
          end
        end

        context "variables" do
          it "accepts literal strings" do
            e = "$env == a_string"
            expect(esig(e)).to eq "==($env, a_string)"
          end
        end
      end
    end
  end
end

