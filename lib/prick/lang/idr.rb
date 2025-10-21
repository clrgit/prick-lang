

module Prick::Lang
  module Idr
    class Node
      include Tree
      include ClassFunctions

      attr_reader :ast # Ast::Node
      forward_to :ast, :token

      # Previous node in block or nil
      attr_accessor :prev

      # Node to build. This is usually equal to self but resources redefine it
      # to be the last node in its block
      def this = self

      # The node to refer to if an object depends on this node. This is usually
      # equal to the previous node but resources have dep equal to the last
      # node in the block
      def dep = prev

      # List of nodes that must preceed this node in the build sequence.
      # Usually equal to [dep] but require statements adds the required
      # resources
      def deps = [dep]

      # Used in debug. May be removed
      attr_reader :serial

      def initialize(parent, ast)
        constrain parent, Idr::Resource, nil
        constrain ast, Ast::Node, nil
        Tree.initialize(self, parent)
        @ast = ast
        @serial = (@@SERIAL += 1)
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
      def path = file.path
    end

    class ExternalCommand < Command
      forward_to :ast, :source, :kind
    end

    class CallCommand < Command
    end

    class RequireCommand < Command
      attr_accessor :uid # UID of required node
      attr_accessor :node # Required node
      def deps = [dep, node]
      def initialize(parent, ast, uid = nil)
        constrain parent, Idr::Resource
        constrain ast, Ast::Reference
        super(parent, ast)
        @uid = uid
      end
    end

    class NopCommand < Command
      def initialize(parent, ast = nil) = super(parent, nil)
    end

    class ProvideCommand < NopCommand
      attr_accessor :uid
      def initialize(parent, ast, uid)
        super(parent, ast)
        @uid = uid
      end
    end

    #
    # R E S O U R C E
    #

    # Can be a schema, phase, provide, or function
    class Resource < Node
      def klass = self.class
      attr_reader :ident # String
      attr_reader :block # [Node]
      def uid = [parent&.uid, ident].compact.join(".")

      def prev = block.first.prev
      def prev=(node) block.first.prev = node end
      def this = block.last
      def dep = block.last

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
      KINDS = Token::PHASES
      ATTRS = KINDS.map(&:downcase)
      PHASES = KINDS.map { |kind| [kind, [kind.downcase, :"#{kind.downcase}="]] }.to_h

      def kind = ast.kind # Symbol
      def read_attr = kind.downcase # Reader method in parent object
      def write_attr = :"#{kind.downcase}=" # Writer method in parent object
    end

    class DefaultPhase < Phase
      attr_reader :kind
      def initialize(parent, kind)
        super(parent, nil)
        @kind = kind
        @ident = read_attr
      end
    end

    class Function < Resource
    end

    class Schema < Resource
      attr_reader :head # Command
      attr_reader :functions # [Function]
      Phase::ATTRS.each { |phase| attr_accessor phase }

      def prev = head.prev
      def prev=(node) head.prev = node end
      def this = term.this
      def dep = this

      def get_phase(ident) = self.send(ident)
      def set_phase(ident, value) = self.send(:"#{ident}=", value)

      # Only used in idr.dump
      def phases = Phase::ATTRS.map { |phase| [phase, self.send(phase)] }.to_h

      def initialize(parent, ast)
        constrain parent, Idr::Resource, nil
        constrain ast, Ast::Schema, Ast::Program
        super(parent, ast)
        @head = self.is_a?(Program) ? NopCommand.new(self) : SchemaCommand.new(self, ast)
        @functions = []
      end
    end

    class Program < Schema
      def key = nil
      def uid = nil
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

