

module Prick::Lang
  module Ast
    class Node
      def title = nil

      def dump() dump_title; dump_children; end
      def dump_title = puts [classname, title].join(' ')
      def dump_children = Kernel.indent { parts.each &:dump }

      def dump_parts
        puts self.classname
        indent {
          for sym, klass in @@PARTS[self.class] || []
            value = get_part(sym)
            if klass == Node.array
              puts "#{sym}: #{klass.classname}[#{@@ARRAY_PARTS[self.class][sym].classname}] = ["
              indent {
                value.each { |v|
                  print "- "
                  indent(bol: false) { v.dump_parts }
                }
              }
              puts "]"

            elsif (@@PARTS[klass] || []).empty? || value.nil?
              if element_klass
                puts "#{sym}: #{klass.classname}[#{element_klass.classname}] = #{value.inspect || 'nil'}"
              else
                puts "#{sym}: #{klass.classname} = #{value.inspect || 'nil'}"
              end

            else
              print "sym: "
              value.dump_parts
            end
          end
        }
      end

      def self.dump_parts
        for key, parts in @@PARTS
          puts key.classname
          indent {
            for sym, klass, element_klass in parts
              if element_klass
                puts "#{sym}: #{klass.classname}[#{element_klass}]"
              else
                puts "#{sym}: #{klass.classname}"
              end
            end
          }
        end
      end

      def inspect() = "#<#{[classname, title].compact.join(' ')}>"
    end

    class Nodes
      def dump() = children.each(&:dump)
      def inspect()
        "#<#{[classname, title].compact.join(' ')} " +
        "element_klass:#{element_klass.classname} size:#{children.size}>"
      end
    end

    class Decl
      def title = @token.kind.to_s.downcase
    end

    class ExternalCommand # Wrong name because 'sql commands gets inlined - back to SourceCommand
      def title = kind.to_s.downcase + (multiline? ? "" : " #{source}")
      def dump_children
        indent { puts source } if multiline?
      end
    end

    class Expr
      def title = token.text
    end

    class Value
      def title = token.text
    end

    class Const
      def title = token.text
    end

    class ReferenceExpr
      def title = ref.token.text
    end
  end
end

