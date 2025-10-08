describe "Prick::Lang" do
  using String::Text

  describe "Analyzer" do
    def file = "file.txt" # Considered a constant

    # Return an Analyzer object
    def make(lines)
      lines = lines.split "\n", -1
      tokenizer = Prick::Lang::Tokenizer.new(file, lines)
      parser = Prick::Lang::Parser.new(tokenizer)
      parser.parse
      oracle = Prick::Lang::Oracle.new({ cmd: "build", env: "prod", user: "me" })
      analyzer = Prick::Lang::Analyzer.new(parser, oracle)
      analyzer
    end

    # Return an Idr object
    def call(lines)
      make(lines).analyze
    end

    def sig(lines)
      idr = call(lines)
      capture { idr.sig }.sub(/^file\s/, "").chomp
    end

#   def sig(lines)
#     idr = call(lines)
#     sig_block(
#
#     if idr.is_a? Prick::Lang::Idr::Program
#       capture {
#         idr.schemas.each { |schema|
#           puts "schema #{schema.ident}"
#           indent {
#             puts sig(schema.block)
#           }
#         }
#       }
#     end
#
#     capture { idr.block.each { |node| node.dump } }
#         .sub(/^file\s/, "")
#         .chomp
#         .sub(/^provide\s.*?\n/m, "")
#   end

#   def sig_block
#   end

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
        if $env == prod
          true.sql
        else
          false.sql
        end
      )
      expect(sig l).to eq %(
        true.sql
      ).align
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
















