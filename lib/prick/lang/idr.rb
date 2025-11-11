

module Prick::Lang
  module Idr
    # Idr nodes are either Command objects, Resource objects, or transient
    # Unresolved objects
    class Node
      include Tree
      include ClassFunctions

      attr_reader :ast # Ast::Node
      forward_to :ast, :token

      # Prick file where this node is defined
      def deffile = token.file

      # Schema this node belongs to. Assigned by the analyzer
      attr_accessor :schema

      # True if the node has changed since last run. Initially false but
      # #dirty! sets it to true
      def dirty? = @dirty

      # True the node is already built. Data are read from the state file and
      # may overlap with #exclude?. Initially false but #built! sets it to true
      def built? = @built

      # True if the node should be excluded from the build. Initially false but
      # #exclude! sets it to true. Excluded nodes are assumed to have already
      # been built - not nodes that should not be built at all
      def excluded? = @excluded

      # True if the node is included in target. Initially false but #include!
      # sets it to true
      def included? = @included

      # Return true if the node should be included when using 'prick build'
      def build?
        included? && !excluded?
      end

      # Return true if the node should be included when using 'prick build'
      def make?
        included? && !excluded? && (dirty? || !built?)
      end

      # Set #built? to true transitively
      def built!
        return if built?
        @built = true
        deps.each &:built!
      end

      # Set #dirty? to true transitively
      def dirty!
        return if dirty?
        @dirty = true
        reqs.each &:dirty!
      end

      # Set #exclude? to true transitively
      def exclude!()
        return if excluded?
        @excluded = true
        deps.each &:exclude!
      end

      # Set #exclude? to true transitively but ignore nodes with #exclude? ==
      # true
      def include!()
        return if included? || excluded?
        @included = true
        deps.each &:include!
      end

      # First node. Default equal to self but resources sets it to the first
      # node in the block
      def head = self

      # Last node. Default equal to self but resources sets it to the last node
      # in the block. This is the node to refer to if an another object depends
      # on this node
      def tail = self

      # List of nodes that this node depends on. The list may only be
      # manipulated using #depend_on
      attr_reader :deps

      # List of nodes that requires this node. The list may only be
      # manipulated using #depend_on
      attr_reader :reqs

      # Used in debug. May be removed
      attr_reader :serial

      def initialize(parent, ast)
        constrain parent, Idr::Resource, nil
        constrain ast, Ast::Node, nil
        Tree.initialize(self, parent)
        @ast = ast
        @serial = (@@SERIAL += 1)
        @deps = []
        @reqs = []
        @dirty = false
        @built = false
        @exclude = false
        @include = false
      end

      # Make self depend on node
      def depend_on(node)
#       head.deps << node.tail
#       node.tail.reqs << self
        head.deps << node
        node.reqs << self
      end

      def Idr.transitive_closure(nodes, method: nil)
        constrain nodes, [Idr::Node]
        constrain method, Symbol, nil
        stack = nodes.dup
        seen = Set.new
        while node = stack.pop
          next if seen.include? node
          seen << node
          if method.nil? || node.send(method)
            if node.is_a?(Resource)
              stack.concat [node.tail]
            else
              stack.concat node.deps #if method.nil? || node.send(method)
            end
          end
#         stack.concat node.deps if method.nil? || node.send(method)
        end
        seen.to_a
      end

      def inspect = "<#{self.class}>"

    private
      @@SERIAL = 0
    end

    #
    # C O M M A N D S
    #

    class Command < Node
    end

    # Artificial node that creates a schema
    class SchemaCommand < Command
    end

    class FileCommand < Command
      alias_method :file, :ast # Ast::File
      def path = ast.value
    end

    class MultilineCommand < Command
      forward_to :ast, :source, :kind
    end

    class SqlCommand < MultilineCommand
    end

    class ExternalCommand < MultilineCommand
      def path = ast.dir
    end

    class CallCommand < Command
    end

    # No OPeration command. Have no function except to serve as anchor or a
    # place to add dependencies
    class NopCommand < Command
      def initialize(parent, ast = nil) = super(parent, ast)
    end

    # Marks the end of a resource
    #
    # the phase and is automatically added to blocks of all resources. It
    # serves as an anchor when chaining and the executor uses it to tell when
    # an object is fully built and doesn't need rebuilding when using 'prick
    # make'. Phases and functions are also marked but this is not used
    class MarkCommand < NopCommand
      def uid = parent.uid
    end

    class RequireCommand < NopCommand
      attr_accessor :uid # UID of required node
      attr_reader :node # Required node
      def node=(node)
        depend_on(node)
        @node = node
      end

      def initialize(parent, ast, uid = nil)
        constrain parent, Idr::Resource
        constrain ast, Ast::Reference
        super(parent, ast)
        @uid = uid
      end
    end

    class MetaCommand < NopCommand
      attr_accessor :schema_name
      attr_accessor :table_name
      def table() = "#{schema_name}.#{table_name}"

      def initialize(parent, ast, schema_name, table_name)
        constrain parent, Idr::Resource
        super(parent, ast)
        @schema_name, @table_name = schema_name, table_name
      end
    end

    class ProvideCommand < NopCommand
      attr_accessor :uid
      def initialize(parent, ast, uid)
        super(parent, ast)
        @uid = uid
      end
    end

    # A CheckCommand is only emitted when a check command was triggered. It
    # invalidates all following nodes within the resource when running 'prick
    # make'
    class CheckCommand < NopCommand
    end

    #
    # R E S O U R C E
    #

    # Can be a schema, phase, provide, or function
    class Resource < Node
      def klass = self.class
      attr_reader :ident # String
      attr_accessor :block # [Node]
      def uid = [parent&.uid, ident].compact.join(".")

      def head = block.first
      def tail = block.last
      def deps = head.deps
      def reqs = tail.reqs

      # These specializations also hits the tail node itself
      def built!() super; tail.built! end
#     def dirty!() super; tail.dirty! end
      def dirty!() super; children.map(&:dirty!) end
      def exclude!() super; tail.exclude! end
      def include!() super; tail.include! end

      def initialize(parent, ast)
        constrain parent, Resource, nil
        constrain ast, Ast::Decl, nil # Should quack #ident, nil because of Program
        super(parent, ast)
        @ident = ast&.ident&.value
        @block = []
      end

      def flatten
        @block = @block.flat_map { |node|
          if node.is_a? Unresolved
            nodes = node.flatten
            node.parent.detach(node)
            nodes
          else
            node
          end
        }
      end
    end

    class Phase < Resource
      KINDS = [:INIT, :THIS] + Token::PHASES.reject { _1 == :INIT }
      ATTRS = KINDS.map(&:downcase)
      PHASES = KINDS.map { |kind| [kind, [kind.downcase, :"#{kind.downcase}="]] }.to_h

      def kind = ast.kind # Symbol
      def read_attr = kind.downcase # Reader method in parent object
      def write_attr = :"#{kind.downcase}=" # Writer method in parent object
    end

    # Default empty phase. Added to the Idr by the analyzer for undefined phases
    class DefaultPhase < Phase
      attr_reader :kind
      def initialize(parent, kind)
        super(parent, nil)
        @kind = kind
        @ident = read_attr
      end
    end

    # The implicit 'this' phase
    class ThisPhase < Phase
      def ident = "this"
      def kind = :THIS
      def read_attr = :this
      def write_attr = :"this="
    end

    class Function < Resource
    end

    class Schema < Resource
      attr_reader :schema_command # Command
      attr_reader :functions # [Function]
      attr_accessor *Phase::ATTRS

      def head = init.head
      def tail = auth.tail
      def deps = init.deps

      def exclude = schema_command.exclude

      # Get/set phase by name
      def get_phase(ident) = self.send(ident)
      def set_phase(ident, value) = self.send(:"#{ident}=", value)

      # Only used in idr.dump
      def phases = Phase::ATTRS.map { |phase| [phase, self.send(phase)] }.to_h

      def initialize(parent, ast)
        constrain parent, Idr::Resource, nil
        constrain ast, Ast::Schema, Ast::Program
        super(parent, ast)
        @schema = self
        @this = ThisPhase.new(self, ast)
        @schema_command = self.is_a?(Program) ? NopCommand.new(self) : SchemaCommand.new(self, ast)
        @functions = []
      end
    end

    class Program < Schema
      def key = nil
      def uid = nil
#     def uid = "public"
      attr_reader :schemas
      def initialize(ast)
        super(nil, ast)
        @schemas = []
      end
    end

    #
    # U N R E S O L V E D
    #

    # Temporary node for unresolved conditional expressions
    class Unresolved < Resource
      forward_to :parent, :klass, :ident, :uid

      # Unresolved Ast node
      attr_reader :unresolved # Ast::Reference

      # UID of the (first) unresolved resource
      attr_reader :unresolved_uid

      def initialize(parent, ast, unresolved, unresolved_uid)
        constrain parent, Idr::Resource
        constrain ast, Ast::Control
        constrain unresolved, Ast::Reference
        constrain unresolved_uid, String
        super parent, nil
        @ast = ast
        @unresolved = unresolved
        @unresolved_uid = unresolved_uid
      end
    end
  end
end

