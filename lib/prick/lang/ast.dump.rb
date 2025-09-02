

module Prick::Lang
  module Ast
    class Node
      # The node's informal name. This is the class name by default but eg.
      # Command redefines it depending on the kind of command (exec/eval/...).
      # Used in #dump and test
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

    class Program < Node
    end

    # Block allows the token to be nil. It defaults to #start_token
    class Block < Node
    end

    class Decl < Node
      def dumpident = "#{Token::TOKENS[kind]} #{name.inspect}"
      def dump = super([block])
    end

    class Phase < Node
      def dumpident = Token::TOKENS[kind]
    end

    class Command < Node
      def dumpname = "#{kind}".capitalize
      def dumpident = source ? source.split("\n").join("; ") : ""
    end

    class If < Node
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

    class IfThen < Node
    end

    class Expr < Node
      def dump = puts source
    end


    # @token is the operator in expression objects
    class UnExpr < Expr
    end

    class BinExpr < Expr
    end

    class ListExpr < Expr
    end

    class VersionExpr < Expr # Token is the 'version' keyword
    end

    class VersionCompareExpr
    end

    class File < Node
      def dumpident = filename
    end

    class Ident < Node
      def dumpsig = name
    end

    class Ver < Node
    end
  end
end

__END__



    class InitBlock < Block
    end

    class FinalBlock < Block
    end

    class MetaBlock < Block #?
    end

    class SeedBlock < Block
    end

    class AuthBlock < Block
    end

    class SchemaStmt < Node
    end

    class OptionStmt < Node
    end

    class CaseStmt < Node
      attr_reader :expr
      attr_reader :when_entries # {expr => Node}
      attr_reader :else_entry # Node or nil
    end

    class CallStmt < Node
      # Single-line command or multiline inline script
      attr_reader :source # String

      # True if source is a multiline inline script
      def multiline?() end

#     # Shell command if single-line, otherwise nil
#     def command() end

      # True if calling a ruby script using require, default false
      attr_reader :ruby
    end

    class ExecStmt < CallStmt
    end

    class EvalStmt < CallStmt
    end

    class SqlFile < File
    end

    class PSqlFile < File
    end

    class FoxFile < File
    end

    class RubyFile < File # ?
      def analyze() CallStmt.new(self, filename, ruby: true) end
    end

    class DirStmt < File
    end

    class PrickStmt < File
    end

    class InitBlock
    end

    class Expr < Node
    end
  end
end
