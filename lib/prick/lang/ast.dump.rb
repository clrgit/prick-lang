

module Prick::Lang
  module Ast
    class Node
      def title = nil

      def inspect() = "#<#{[classname, title].compact.join(' ')}>"

      def dump() dump_title; dump_children; end
      def dump_title = puts [classname, title].join(' ')
      def dump_children = Kernel.indent { parts.each { |k,v| v.dump if !v.nil?  } }
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

    class RuntimeExpr
      def dump = puts "#{self.classname} #{ident} #{words.map(&:to_s).join(', ')}"
    end

    class ReferenceExpr
      def dump = puts "#{self.classname} #{ref}"
    end
  end
end

