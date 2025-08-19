module Prick::Lang
  module Ast
    class Node
      attr_reader :parent # Node or nil
      attr_reader :children # [Node]
      attr_reader :token

      forward_to :token, :lineno, :charno

      def initialize(parent, token)
        @parent = parent and parent.children << self
        @children = []
        @token = token
      end
    end

    class Program < Node
      def initialize(file)
        super(nil, Token.new(file, 1, 1, "", :PROGRAM)
      end
    end

    class Block < Node
      def name = @token.text
      alias_method :start_token, :token
      attr_accessor :stop_token, :token
      def initialize(parent, start_token, stop_token = start_token)
        super(parent, start_token)
        @stop_token = stop_token
      end
    end

#   class SchemaStmt < Block
#     attr_reader :name
#
#
#   end










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
      attr_reader :expr # Expr
      attr_reader :then # Block
      attr_reader :else # Block

      def initialize(token, parent, expr, then_, else_)
        super(token, parent)
        @expr, @then, @else = expr, then_, else_
      end

      def analyze(parent) Idr::IfStmt.new(self, parent, expr, @then.analyze, @else.analyze) end
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

    class FileStmt < Node
      forward_to :token, :filename, :extname
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
