module Prick::Lang
  module Ast
    class Node
      attr_accessor :parent # Node or nil
      attr_accessor :children # [Node]
      attr_accessor :token

      forward_to :token, :lineno, :charno

      def initialize(parent, token)
        @parent = parent and parent.children << self
        @children = []
        @token = token
      end
    end

    class Block < Node
      alias_method :nodes, :children
      def lineno() @lineno ||= children.first&.lineno or raise end
      def charno() @charno ||= children.first&.charno or raise end
    end

    class Program < Block
    end

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

    class IfStmt < Node
      attr_accessor :expr # Expr
      attr_accessor :then # Block
      attr_accessor :else # Block

      def initialize(token, parent, expr, then_, else_)
        super(token, parent)
        @expr, @then, @else = expr, then_, else_
      end

      def analyze(parent) Idr::IfStmt.new(self, parent, expr, @then.analyze, @else.analyze) end
    end

    class CaseStmt < Node
      attr_accessor :expr
      attr_accessor :when_entries # {expr => Node}
      attr_accessor :else_entry # Node or nil
    end

    class CallStmt < Node
      # Single-line command or multiline inline script
      attr_accessor :source # String

      # True if source is a multiline inline script
      def multiline?() end

#     # Shell command if single-line, otherwise nil
#     def command() end

      # True if calling a ruby script using require, default false
      attr_accessor :ruby
    end

    class ExecStmt < CallStmt
    end

    class EvalStmt < CallStmt
    end

    class FileStmt < Node
      attr_accessor :filename
    end

    class SqlFileStmt < FileStmt
    end

    class PSqlFileStmt < FileStmt
    end

    class FoxFileStmt < FileStmt
    end

    class RubyFileStmt < FileStmt # ?
      def analyze() CallStmt.new(self, filename, ruby: true) end
    end

    class DirStmt < FileStmt
    end

    class PrickStmt < FileStmt
    end

    class InitBlock
    end

    class Expr < Node
    end
  end
end
