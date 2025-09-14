

module Prick::Lang
  module Ast
    class Node
      def title = nil

      def dump() dump_title; dump_children; end
      def dump_title = puts [classname, title].join(' ')
      def dump_children = Kernel.indent { children.each &:dump }

      def dump_parts
        puts self.classname
        indent {
          for sym, klass, element_klass in @@PARTS[self.class] || []
            value = get_part(sym)
            if klass == Nodes
              puts "#{sym}: #{klass.classname}[#{element_klass.classname}] = ["
              indent {
                value.children.each { |v|
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
      def inspect()
        "#<#{[classname, title].compact.join(' ')} " +
        "element_klass:#{element_klass.classname} size:#{children.size}>"
      end
    end

    class Decl
      def title = @token.kind.to_s.downcase
    end

    class SourceCommand
      def title = kind.downcase
      def dump_children = indent { puts source }
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
  end
end

