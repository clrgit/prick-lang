

module Prick::Lang
  module Ast
    class Node
      # The node's informal name. This is the class name by default but eg.
      def dumpname = classname

      # The node's identifier (possibly nil). Used in #dump and test
      def dumpident = nil

      # Signature of a node (token-kind/class + ident). Used in #dump and test
      def dumpsig = [dumpname, dumpident].compact.join(" ")

      # Dump an Ast node hierarchically
      def dump(nodes = children)
        puts dumpsig
        indent { nodes.each &:dump }
      end

      def inspect() = "#<#{dumpsig}>"
    end

    class Program
    end

    # Block allows the token to be nil. It defaults to #start_token
    class Block
    end

    class Decl
      def dumpident = "#{Token::TOKENS[kind]} #{name.inspect}"
      def dump = super([block])
    end

    class Require
      def dump
        puts "#{dumpsig} #{refs.map(&:ref).join(", ")}"
      end
    end

    class Phase
      def dumpident = Token::TOKENS[kind]
    end

    class Command
      def dumpname = "#{kind}".capitalize
      def dumpident = source ? source.split("\n").join("; ") : ""
    end

    class If
      def dump
        keyword = "If"
        for if_then in if_thens
          puts "#{keyword} #{if_then.expr.source}"
          keyword = "Elsif"
          indent { if_then.then_.dump }
        end
        if else_
          puts "Else"
          indent { else_.dump }
        end
      end
    end

    class IfThen
    end

    class Expr
      def dump = puts source
    end


    # @token is the operator in expression objects
    class UnExpr
    end

    class BinExpr
    end

    class ReferenceExpr
    end

    class VersionExpr
    end

    class VersionCompareExpr
    end

    class File
      def dumpident = filename
    end

    class Ident
      def dumpsig = name
    end

    class Ver
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
