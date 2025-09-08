

# while ! eof
#   analyze until if statement
#   if if-statement involves schema, object, or resource
#     emit 'unevaluated'
#     skip if-statement
#   else
#     eval if-statement
#     skip false-branch
#   end
#
# while unevaluated control statements
#
# end
#
# Example:
#   t.prick:
#     if resource s.r
#       provide t.r
#     else
#       something # Negative assert
#     end
#
#   s.prick:
#     if resource t.r
#       provide s.r
#     end
#
# Handled by detecting dependencies when a provide is used within a dynamic
# control statement. In the example, t.r will depend on s.r and s.r will depend
# on t.r so the analyzer will detect a circular reference when computing the
# build order. This should be done in the check phase: A resource dependency check
#
# Example:
#   t.prick:
#     provide t.r
#     require s.r
#
#   s.prick:
#     provide s.r
#     require t.r
#
# Example
#   if resource t.r or resource s.r # Assert truish/falsy expression (lazy evaluated)
#     # Is t.r or s.r true?
#   end
#


module Prick::Lang
  module Idr
    class Node; end

    class Schema
      attr_reader :init, :meta, :seed, :auth, :final
      attr_reader :resources
      attr_reader :functions

    end

    class Block < Node
      attr_reader :stmts

    end

    class Source < Node; end
    class Stmt < Node; end

  end
end


module Prick::Lang
  module Checker

    class Decl
      @@IN_SCHEMA = false
      @@IN_FUNCTION = false

      def check
        check_nesting(&block)
      end

      def check_nesting
        if kind == :SCHEMA
          @@IN_SCHEMA == false or error "Can't have schemas within schemas"
          @@IN_FUNCTION == false or error "Can't have schemas within functions"
          @@IN_SCHEMA = true
          yield
          @@IN_SCHEMA = true
        else
          @@IN_FUNCTION == false or error "Can't have functions within functions"
          @@IN_FUNCTION = true
          yield
          @@IN_FUNCTION = true
        end
      end

      def check_duplicate

      end
    end
  end
end



__END__





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
