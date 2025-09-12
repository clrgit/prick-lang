

module Prick::Lang
  module Ast
    class Node
      def classname = self.class.to_s.sub(/.*::/, "")
      def title = nil

      def dump() dump_title; dump_children; end
      def dump_title = puts [classname, title].join(' ')
      def dump_children = Kernel.indent { children.each &:dump }

      def inspect() = "#<#{[classname, title].compact.join(' ')}>"
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

