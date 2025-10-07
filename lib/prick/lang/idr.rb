

module Prick::Lang
  module Idr
    class Node
      include ClassFunctions

      attr_reader :parent # Idr::Resource or nil for top-level Program object

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
        super(parent, ast)
        @ident = ast&.ident&.value
        @block = []
      end

      def flatten
        @block = @block.flat_map { |node|
          node.is_a?(Unresolved) ? node.flatten : node
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
        constrain parent, Idr::Program, nil
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
#       puts "Unresolved#initialize"
#       puts "  parent: #{parent.classname}"
#       puts "  ast: #{ast.classname}"
#       puts "  unresolved: #{unresolved.classname}"
#       puts "  unresolved_uid: #{unresolved_uid.inspect}"
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

    # An unresolved object quacks like the containing resource but has its own
    # block. By pushing an unresolved object to the oracle's context stack, the
    # usual #build_X methods will still work. Unresolved objects are later
    # flattened into the parent's block
#   class Unresolved < Node
#     attr_reader :unresolved # Ast::Reference
#
#     # UID of resource
#     def uid = parent.uid
#   end
  end
end





__END__

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
    # R E Q U I R E
    #
    class RequireCommand < Node
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

