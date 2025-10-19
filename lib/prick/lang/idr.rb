

module Prick::Lang
  module Idr
    class Node
      include Tree
      include ClassFunctions

      attr_reader :ast # Ast::Node
      forward_to :ast, :token

      # Previous node or nil
      attr_accessor :prev

      # Node to build. This is usually equal to self but resources redefine it
      # to be the last node in the block
      def this = self

      # If a

#     # The node to refer to if an object depends on this node. This is usually
#     # equal to self but resources have dep equal to the last node in the
#     # block
      def dep = prev

      # List of nodes that must preceed this node in the build sequence.
      # Initially the empty list, assigned later by the analyzer
      attr_reader :dependencies # [Node]

      # Used in debug. May be removed
      attr_reader :serial

      def initialize(parent, ast)
        constrain parent, Idr::Resource, Provide, nil
        constrain ast, Ast::Node, nil
        Tree.initialize(self, parent)
        @ast = ast
        @requires = []
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

#   class ProvideCommand < Command
#     attr_accessor :provide # Resource
#     def initialize(parent, ast)
#       super(parent, ast)
#       @provide = Provide.new(self, ast)
#     end
#   end

    class RequireCommand < Command
      attr_accessor :uid # UID of required node
      attr_accessor :node # Required node
      def initialize(parent, ast, uid = nil)
        constrain parent, Idr::Resource
        constrain ast, Ast::Reference
        super(parent, ast)
        @uid = uid
      end
    end

    class NopCommand < Command
      def initialize(parent) = super(parent, nil)
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
        constrain parent, Resource, Provide, nil
        constrain ast, Ast::Decl, Ast::Provide, nil # Should quack #ident, nil because of Program
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
      ATTRS = Token::PHASES.map(&:downcase)
      def kind = ast.kind # Symbol
      def read_attr = kind.downcase # Reader method in parent object
      def write_attr = :"#{read_attr}=" # Writer method in parent object
    end

    class DefaultPhase < Phase
      attr_reader :kind
      def initialize(parent, kind)
        super(parent, nil)
        @kind = kind
        @ident = read_attr
      end
    end

    class Provide < Resource
      attr_accessor :prev
      def this = self
      def dep = prev # Provide doesn't have a block
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

