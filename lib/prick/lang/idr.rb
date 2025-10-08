

module Prick::Lang
  module Idr
    class Node
      include ClassFunctions

      attr_accessor :parent # Idr::Resource or nil for top-level Program object

      attr_reader :ast # Ast::Node
      forward_to :ast, :token

      def initialize(parent, ast)
        constrain parent, Idr::Resource, nil
        constrain ast, Ast::Node, nil
        @parent = parent
        @ast = ast
      end

      def inspect = "<#{self.class}>"
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
      def initialize(parent, ast, uid = nil)
        constrain parent, Idr::Resource
        constrain ast, Ast::Reference
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
      def initialize(parent, ast)
        constrain ast, Ast::Decl, Ast::Provide, nil # Should quack #ident, nil because of Program
        constrain parent, Resource, nil
        super(parent, ast)
        @ident = ast&.ident&.value
        @block = []
      end

      def flatten
        @block = @block.flat_map { |node|
          if node.is_a? Unresolved
            nodes = node.flatten
#           nodes.each { _1.parent = self }
            nodes
          else
            node
          end
#         node.is_a?(Unresolved) ? node.flatten.tap { |node| node.parent = self } : node
        }
      end
    end

    class Phase < Resource
      ATTRS = Token::PHASES.map(&:downcase)
      def kind = ast.kind # Symbol
      def read_attr = ast.kind.downcase # Reader method in parent object
      def write_attr = :"#{read_attr}=" # Writer method in parent object
    end

    class Provide < Resource
    end

    class Function < Resource
    end

    # TODO: End-of-schema-marker (or use schema itself - like other resources)
    class Schema < Resource
      attr_reader :head # Command
      attr_reader :functions # [Function]
      Phase::ATTRS.each { |phase| attr_accessor phase }
      def phases = Phase::ATTRS.map { |phase| [phase, self.send(phase)] }.to_h
      def initialize(parent, ast)
#       constrain parent, Idr::Program, nil
        constrain parent, Idr::Resource, nil
        constrain ast, Ast::Schema, Ast::Program
        super(parent, ast)
        @head = SchemaCommand.new(self, ast) if !self.is_a?(Program)
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

