

#module Prick::Lang
# module Idr
#   class Node; end
#
#   class Block < Node; end
#   class Source < Node; end
#   class Stmt < Node; end
#
# end
#end












module Prick::Lang
  module Idr
    class Node
      attr_accessor :ast_node

      attr_accessor :parent # Node or nil
      attr_accessor :children # [Node]

      forward_to :ast_node, :lineno, :charno

      def generate() end
    end

    class Block < Node
      alias_method :nodes, :children

      def generate()
        nodes.map(&:generate)
      end
    end

    class Program < Block
    end

    class IfStmt < Node
      attr_accessor :expr
      attr_accessor :then
      attr_accessor :else

      def generate
        if expr.value
          @then.generate
        else
          @else.generate
        end
      end
    end

    class CaseStmt < Node
      attr_accessor :expr
      attr_accessor :when_entries # {expr => Node}
      attr_accessor :else_entry # Node or nil

      def generate
        for entry, stmt in when_entries
          if entry === expr.value
            stmt.generate
            return
          end
        end
        if else_entry
          else_entry.generate
        end
      end
    end

    class CallStmt < Node
      # Single-line command or inline script
      attr_accessor :source

      # Command line if single-line, otherwise nil
      def command() end

      # True if calling a ruby script using require
      forward_to :ast_node, :ruby

#     def initialize(parent, ast_node,
    end

    class ExecStmt < CallStmt
    end

    # Required ruby script, ignore output
    class RubyStmt < ExecStmt
    end

    class EvalStmt < CallStmt
    end

    class FileStmt < Node
      attr_accessor :file
    end

    class SqlFileStmt < FileStmt
    end

    class PSqlFileStmt < FileStmt
    end

    class FoxFileStmt < FileStmt
    end

    class PrickStmt < FileStmt
    end

    class DirStmt < FileStmt
    end

    class Expr < Node
      forward_to :ast_node, :expr
      def generate() raise end
      def value() @value ||= within_some_context { eval expr } end
    end
  end
end
