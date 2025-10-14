describe "Prick::Lang" do
  using String::Text

  describe "Evaluator" do
    def file = "file.txt" # Considered a constant

    # Return an Analyzer object
    def make(lines)
#     lines = lines.split "\n", -1
#     tokenizer = Prick::Lang::Tokenizer.new(file, lines)
#     parser = Prick::Lang::Parser.new(tokenizer)
#     parser.parse
#     oracle = Prick::Lang::Oracle.new({ cmd: "build", env: "prod", user: "me", ver: Semver.new("1.2.3") })
#     analyzer = Prick::Lang::Analyzer.new(parser, oracle)
#     analyzer

      compiler = make_compiler
      compiler.parser.parse(file, lines.split("\n", -1))
      compiler.analyzer
    end

    # Return an Idr object
    def call(lines)
      make(lines).analyze
    end

    def sig(lines)
      idr = call(lines)
      capture { idr.sig }.gsub(/^file\s/m, "").chomp
    end

    it "evaluates known references to true" do
      l = %(
        provide r

        if r?
          true.sql
        else
          false.sql
        end
      )
      expect(sig(l)).to eq %(
        provide r
        true.sql
      ).align
    end

    it "evaluates unknown references to false" do
      l = %(
        if r?
          true.sql
        else
          false.sql
        end
      )
      expect(sig(l)).to eq %(
        false.sql
      ).align
    end

    it "takes later-defined resources into account" do
      l = %(
        if r?
          true.sql
        else
          false.sql
        end

        provide r
      )
      expect(sig(l)).to eq %(
        true.sql
        provide r
      ).align
    end

    it "evaluates variables" do
      l = %(
        if $env = prod
          true.sql
        else
          false.sql
        end
      )
      expect(sig l).to eq %(
        true.sql
      ).align
    end

    it "evaluates true/false constants" do
      l = %(
        if true
          true.sql
        else
          false.sql
        end
        if false
          true.sql
        else
          false.sql
        end
      )
      expect(sig l).to eq %(
        true.sql
        false.sql
      ).align
    end

    it "evaluates version expressions" do
      l = %(
        if $ver ~> 1.2
          true.sql
        else
          false.sql
        end
        if $ver ~> 1.3
          true.sql
        else
          false.sql
        end

      )
      expect(sig l).to eq %(
        true.sql
        false.sql
      ).align
    end

    context "evaluates 'in' expressions" do
      it "with a multi-element list" do
        l = %(
          if $env ^ (prod, test)
            true.sql
          else
            false.sql
          end
        )
        expect(sig l).to eq %(
          true.sql
        ).align
      end
      it "with a single-element list" do
        l = %(
          if $env ^ (prod)
            true.sql
          else
            false.sql
          end
        )
        expect(sig l).to eq %(
          true.sql
        ).align
      end
      it "with an empty list" do
        l = %(
          if $env ^ ()
            true.sql
          else
            false.sql
          end
        )
        expect(sig l).to eq %(
          false.sql
        ).align
      end
    end

    context "evaluates '%' expressions" do
      it "with a multi-element list" do
        l = %(
          if $env % (prod, test)
            true.sql
          else
            false.sql
          end
        )
        expect(sig l).to eq %(
          true.sql
        ).align
      end
      it "with a single-element list" do
        l = %(
          if $env % (prod)
            true.sql
          else
            false.sql
          end
        )
        expect(sig l).to eq %(
          true.sql
        ).align
      end
      it "with an empty list" do
        l = %(
          if $env % ()
            true.sql
          else
            false.sql
          end
        )
        expect(sig l).to eq %(
          false.sql
        ).align
      end
      it "with a value" do
        l = %(
          if $env % prod
            true.sql
          else
            false.sql
          end
        )
        expect(sig l).to eq %(
          true.sql
        ).align
      end
    end
  end
end


