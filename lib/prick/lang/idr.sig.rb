
module Prick::Lang::Idr
  class Resource
    def sig = sig_block
    def sig_block = block.each { |node| node.dump }
  end

  class Program
    def sig
      schemas.each { |s|
        puts "schema #{s.ident}"
        indent { s.sig_block }
      }
      super
    end
  end
end

__END__

    def sig(lines)
      idr = call(lines)
      sig_block(

      if idr.is_a? Prick::Lang::Idr::Program
        capture {
          idr.schemas.each { |schema|
            puts "schema #{schema.ident}"
            indent {
              puts sig(schema.block)
            }
          }
        }
      end
#
      capture { idr.block.each { |node| node.dump } }
          .sub(/^file\s/, "")
          .chomp
#         .sub(/^provide\s.*?\n/m, "")
    end

    def sig_block
    end

