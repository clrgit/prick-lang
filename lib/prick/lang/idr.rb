
module Prick::Lang
  module Idr
    class AbstractNode
      attr_accessor :prev # Node. Previous node. May be nil
      attr_reader :ast # Ast::Node
      def token = ast.token
      attr_reader :deps # Node. Dependencies in addition to #prev. In reality either one or none object

      def initialize(prev, ast)
        @prev = prev
        @ast = ast
      end
    end

    class UnresolvedNode < AbstractNode
    end

    # Artificial node used for anchoring
#   class Anchor < AbstractNode
#     attr_reader :uid
#   end

    class Node < AbstractNode
      attr_accessor :node # First node. Default equal to self
    end

    class Program < Node
    end

    # Can be a schema, provide, or function
    class Resource < Node
      attr_accessor :ident # String
      attr_accessor :uid # String
      attr_accessor :nodes # [Node]
      def node = nodes.first
      attr_accessor :head # Entry node, only used by Schema. Embedded objects depend on head. FIXME: They do?
      attr_accessor :tail # Last node. External objects depend on tail. Equal to :head for simple objects
    end

    # TODO: End-of-schema-marker (or use schema itself - like other resources)
    class Schema < Resource
      attr_accessor :functions # {uid=>Function}
    end

    class Provide < Resource
      def initialize(prev, ast, schema)
        constrain ast, Ast::Provide
        super(prev, ast)
        @ident = ast.ident
        @uid = ast.uid
      end
    end

    class Require < Node
      attr_accessor :resource
    end

    class Command < Node
      attr_accessor :kind
      def is_referenced?() = raise
    end

    class FileCommand < Command
    end

    class InlineCommand < Command
    end

    class SchemaCommand < InlineCommand
    end

    class SourceCommand < Command
      attr_accessor :source
    end

    class CallCommand < Command
    end
  end
end








#class Oracle
# def truths = @resources.filter_map { _2 and _1 }
# def falses = @resources.filter_map { ! _2 and _1 }
#
# def initialize
#   @resources = {} # Map from resource name to true/false
# end
#
# def add(resource, truish)
#   ! present(resource) or raise ArgumentError "Duplicate key"
#   @resources[resource] = truish
# end
#
# def present?(source) = @resources.key?(resource)
# def truish?(resource) = @resources[resource]
# def falsy?(resource) = !@resources[resource]
#end

#schema.sql
#provide decl
#a.sql
#provide a
#b.sql
#require x
#c.sql
#provide b
#d.sql
#provide schema
#
#a -> decl
#b -> a, x
#schema -> b
#
#Resources:
# decl:
#   schema.sql
# a -> decl
#   a.sql
# b -> a
#   b.sql
#   require x
#   c.sql
# d.sql
# schema -> b
#   require b

# Lumps of simple statements are groups. They're treated as one unit to reduce
# the workload of the dependency analysis. 'require' and 'provide' and
# if-statements involving 'schema', 'object', or 'resource' expressions are not
# included in statement groups


# The Ast is compiled using frames so that compilation can be interrupted. A
# frame is just the resource object that encloses the code plus the point where
# the compiled Idr should be attached
#
#   def compile(frame, attach_point, ast_node)
#     return a block. The block may have #evaluated? false/nil
#   end
#
# At the end of a compilation pass we'll have a list of unresolved resources

module Prick::Lang
  module Idr
    class Node
      include Tree
      alias_method :scope, :parent

      def initialize(parent)
        @children = []
        parent && attach(parent)
      end
    end

    class Block < Node
      alias_method :stmts, :children
    end

    class Resource < Block
      attr_reader :parent # SchemaDecl
      attr_reader :provide
      attr_reader :block

      attr_reader :requires # [Resource]
      alias_method :provide, :ident

      def uid() @uid ||= [parent&.uid, provide].compact.join('.') end

      def evaluated? = !@presence.nil?
      def present? = @presence
      def absent? = !@presence

      def present! @present = true end
      def absent! @present = false end

      def initialize(parent, ident)
        super parent
        @ident = ident
        @requires = Set.new
      end
    end

    # This models only the postgres schema and phases. The actual implementation of
    # the schema is the #defn Schema object. The intention is that the first
    # statement of the schema depends on the declaration only and not the full
    # schema
    class SchemaDecl < Resource
      def defn = @children.first # Always a Schema
      attr_accessor :init, :meta, :seed, :auth, :final
      def initialize(..., defn = nil)
        super ...
        assign(:defn, defn)
      end
    end

    # Full schema definition
    class Schema < Resource
      alias_method :program, :parent

      alias_method :decl, :parent # Always a SchemaDecl
      attr_reader :block
      forward_to :decl, :init, :meta, :seed, :auth, :final
      def initialize(decl, block)
        super decl
        assign(:block, block)
      end
    end

    class Stmt < Node
    end

    class UnresolvedStmt < Stmt
      attr_reader :stmt
      attr_reader :unresolved_resource # The first resource in the stmt
    end

    class If < Stmt
      attr_reader :if_thens # [IfThen]
      attr_reader :block
      def initialize(..., if_thens, block)
        super ...
        if_thens.each { attach _1 }
        assign(:block, block)
      end
    end

    class IfThen < Stmt
      attr_reader :expr
      attr_reader :block
      forward_to :expr, :resolvable?
      def intialize(..., expr, block)
        super ...
        assign(:expr ,expr)
        assign(:block, block)
      end
    end

    class Command < Stmt # Stand-in
      attr_reader :text # String (for now)
      def initialize(parent, text)
        super(parent)
        @text = text
      end
    end

    class Expr < Node
      attr_reader :resolvable? # True if the expression only involves evaluated resources
      attr_reader :unresolved # List of unresolved resources in the expression

      # This intentionally only caches when resolvable goes to true
      def resolvable?() @resolveable? ||= children.all?(&:resolvable?) end

      # List of unresolved resources
      def unresolved = recursive_unresolved([])

      def eval() = raise

    private
      def recursive_unresolved(a)
        children.reject { |c| c.instance_variable_get(:@resolvable) }.each { |c|
          if c.is_a? ResourceValue
            a << c if !c.resolvable?
          end
          c.recursive_unresolved(a)
        }
        a
      end
    end

    class BinExpr < Expr
      attr_reader :oper # Symbol
      attr_reader :left # Expr
      attr_reader :right # Expr
      def initialize(..., oper, left, right)
        super ...
        @oper = oper
        assign :left, left
        assign :right, right
      end

      def eval
        case oper
          :OROR; left.eval || right.eval
          :ANDAND; left.eval && right.eval
          :LT; left < right
          :LE; left <= right
          :EQEQ; left == right
          :NEQ; left != right
          :GE; left >= right
          :GT; left > right
          :TIGT left.squiggle?(right)
        else
          raise InternalError
        end
      end
    end

    class UnExpr < Expr
      attr_reader :oper # Symbol
      attr_reader :arg # Expr

      def initialize(..., oper, arg)
        super ...
        @oper = oper
        assign :arg, arg
      end

      def eval
        case oper
          when :EXCLAIM; ! arg.eval
        else
          raise InternalError
        end
      end
    end

    class SimpleExpr < Expr
      def eval = value
    end

    class ResourceValue < Expr
      attr_reader :resource

      def initialize(..., resource)
        super ...
        assign :resource, resource
      end

      def resolvable? = resource.evaluated?
      def unresolved = resolvable? ? [self] : []
      def value
        resolveable? or raise InternalError
        resource.present?
      end
    end
  end
end

__END__



# Truths
#
# Falses



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
#     require s.r
#     provide t.r
#
#   s.prick:
#     require t.r
#     provide s.r
#
# Results in the dependencies that contains a cycle:
#
#   t.r -> t
#   t -> s.r
#   s.r -> s
#   s -> t.r
#
# Maybe a similar problem with if-statements. Example:
#
#   if ! t # set false # conflict if evaluated last
#     s
#   end
#
#   if s # set truth
#     t # conflict because t is already marked falsy
#   end
#
# Stop-go compilation makes it possible to see resource that are not compiled
# yet. Example:
#
#   s1.prick
#     if s2
#       ...
#     end
#
#   s2.prick
#     ...
#
#   main.prick
#     s1
#     s2
#
# Algorithm
#
#   compile_as_far_as_possible
#   check for cyclic dependencies
#   loop
#     find expressions that evaluates to true/false (ie. skip unevaluated)
#       compile_as_far_as_possible
#     end
#     if no expression evaluated to true
#       # set "some" resource to false <- Shouldn't matter which one vs. longest/shortest FIXME
#       compile_as_far_as_possible
#     end
#
#
#
#
#
#
#
#
#
# Example
#   t.prick:
#     if x
#       require s.prick
#     end
#
#   s.prick:
#     if ! x
#       require t.prick
#     end
#
#
# Example
#   if t (*)
#     s
#   end
#
#   if s (*)
#
#   end
#
#   u.sql
#   provide u
#
#   How to proceed?
#
#   If t is evaluated first, then s will not be included, but
#
#
#
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
