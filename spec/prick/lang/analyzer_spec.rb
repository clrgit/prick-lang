describe "Prick::Lang" do
  using String::Text

  describe "Analyzer" do
    def file = "file.prick" # Considered a constant

    # Return an Analyzer object
    def make(lines)
      compiler = make_compiler
      compiler.parser.parse(file, lines.split("\n", -1))
      compiler.convert
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

    it "allows nested definitions" do
      l = %(
        if r?
          provide p
        end

        if r?
          if p?
            true.sql
          else
            false.sql
          end
        end

        provide r
      )
      expect(sig(l)).to eq %(
        provide p
        true.sql
        provide r
      ).align
    end

    it "allows schemas within if statements" do
      l = %(
        provide r
        if r?
          schema s {
            s.sql
          }
        end
      )
      expect(sig l).to eq %(
        schema s
          file s.sql
        provide r
      ).align
    end
  end
end
















