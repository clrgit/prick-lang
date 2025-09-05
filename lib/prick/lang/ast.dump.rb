

module Prick::Lang
  module Ast
    class Node
      def classname = self.class.to_s.sub(/.*::/, "")
      def title = nil

      def dump() dump_title; dump_children; end
      def dump_title = puts [classname, title].join(' ')
      def dump_children = Kernel.indent { children.each &:dump }

      def inspect() = "#<#{[classname, ident].compact.join(' ')}>"
    end

    class Decl
      def title = @token.kind.to_s.downcase
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

__END__



    class InitBlock
    end

    class FinalBlock
    end

    class MetaBlock
    end

    class SeedBlock
    end

    class AuthBlock
    end

    class SchemaStmt
    end

    class OptionStmt
    end

    class CaseStmt
      attr_reader :expr
      attr_reader :when_entries # {expr => Node}
      attr_reader :else_entry # Node or nil
    end

    class CallStmt
      # Single-line command or multiline inline script
      attr_reader :source # String

      # True if source is a multiline inline script
      def multiline?() end

#     # Shell command if single-line, otherwise nil
#     def command() end

      # True if calling a ruby script using require, default false
      attr_reader :ruby
    end

    class ExecStmt
    end

    class EvalStmt
    end

    class SqlFile
    end

    class PSqlFile
    end

    class FoxFile
    end

    class RubyFile
      def analyze() CallStmt.new(self, filename, ruby: true) end
    end

    class DirStmt
    end

    class PrickStmt
    end

    class InitBlock
    end

    class Expr
    end
  end
end
