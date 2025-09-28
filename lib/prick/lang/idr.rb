
module Prick::Lang
  module Idr
    class Node < Part
      include ClassFunctions

      attr_reader :ast # Ast::Node
      def token = ast.token

      def initialize(ast)
        constrain ast, Ast::Node if !ast.nil?
        super()
        @ast = ast
      end
    end

    class Nodes < Node
      include Parts

      # #ast is initially nil but redefined to the ast of the first node
      def ast = @ast || children.first&.ast

      # Outermost Program object
      def program = @program ||= whole.program

      # Enclosing Schema object. Outermost phases and functions have program
      # as schema
      def schema() = @schema ||= whole.schema

      def initialize(ast, element_klass)
        Parts.initialize(self, element_klass)
        super(ast)
      end
    end

    #
    # C O M M A N D S
    #

    class Command < Node
      attr_accessor :kind
    end

    # Artificial node that creates a schema
    class SchemaCommand < Command
    end

    class FileCommand < Command
      alias_method :file, :ast
      def path = file.path
    end

    class ExternalCommand < Command
      forward_to :ast, :source
    end

    class CallCommand < Command
    end

    #
    # R E S O U R C E
    #

    # Can be a schema, phase, provide, or function
    class Resource < Node
      forward_to :ast, :ident
      attr_reader :uid
      part :block, [Node] # Command|Require
      def initialize(ast, uid)
        super(ast)
        @uid = uid
      end
    end

    class Phase < Resource
      def kind = ast.kind
      def attr = ast.kind.downcase # Attribute name in enclosing object
    end

    class Provide < Resource
    end

    class Function < Resource
    end

    # TODO: End-of-schema-marker (or use schema itself - like other resources)
    class Schema < Resource
      def schema = self
      part :head, Command
      part :functions, [Function]
      Token::PHASES.each { |phase| part phase.downcase, Phase }
      def provides() = nil # TODO
    end

    #
    # P R O G R A M
    #

    class Program < Schema
      def program = self
      part :schemas, [Schema]
    end

    #
    # R E Q U I R E
    #
    class Require < Node
      def schema_or_phase_or_function = raise

      alias_method :schema, :parent
      attr_reader :uid
      attr_accessor :node # Required entry node
      def initialize(ast, uid)
        constrain ast, Ast::Reference
        super(ast)
        @uid = uid
      end
    end

    #
    # U N R E S O L V E D
    #

    class Unresolved < Node
      attr_reader :unresolved # Ast::Reference

      # The uid of the unresolved resource
      attr_reader :uid

      def initialize(ast, unresolved, uid)
        constrain unresolved, Ast::Reference
        super ast
        @unresolved = unresolved
        @uid = uid
      end
    end
  end
end

