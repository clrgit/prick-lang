describe "Prick::Lang" do
  using String::Text

  describe "Analyzer" do
    def file = "file.txt" # Considered a constant

    def make(lines)
      lines = lines.split "\n", -1
      tokenizer = Prick::Lang::Tokenizer.new(file, lines)
      parser = Prick::Lang::Parser.new(tokenizer)
      parser.parse
      oracle = Prick::Lang::Oracle.new({ cmd: "build", env: "prod", user: "me" })
      analyzer = Prick::Lang::Analyzer.new(parser, oracle)
      analyzer
    end

    def call(lines)
      make(lines).analyze
    end

    def sig(lines)
      idr = call(lines)
      capture { idr.block.each { |node| node.dump } }
          .sub(/^provide\s.*?\n/m, "")
          .sub(/^file\s/, "")
          .chomp
    end

    it "evaluates known references to true" do
      l = %(
        provide r

        if resource r
          true.sql
        else
          false.sql
        end
      )
      expect(sig(l)).to eq %(
        true.sql
      ).align
    end

    it "evaluates unknown references to false" do
      l = %(
        if resource r
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
        if resource r
          true.sql
        else
          false.sql
        end

        provide r
      )
      expect(sig(l)).to eq %(
        true.sql
      ).align
    end

    it "allows nested definitions" do
      l = %(
        if resource r
          provide p
        end

        if resource r
          if resource p
            true.sql
          else
            false.sql
          end
        end

        provide r
      )
      expect(sig(l)).to eq %(
        true.sql
        provide r
      ).align
    end
  end
end
__END__
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


    it "asdf" do
      l = %(
        provide r

        if resource r
          schema s {
            true.sql
          }
        else
          false.sql
        end
      )
      expect(sig(l)).to eq %(
        true.sql
      ).align
    end

