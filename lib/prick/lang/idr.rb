
module Prick::Lang
  module Idr
    class Node < Part
      include ClassFunctions

      attr_reader :ast # Ast::Node
      def token = ast.token

      def initialize(parent, ast)
        @ast = ast
        Tree.initialize(self, parent)
      end

      def dump(*text) = dump_impl(*text)
      def dumps(*text, nodes) dump_impl(*text); indent { nodes.each &:dump } end

      def inspect = "<#{self.classname}>"

    private
      # To avoid endless recursion when #dump is redefined
      def dump_impl(*text) = puts ([self.classname] + text).compact.join(" ")
    end

    class Nodes < Node
      include Parts
      def initialize(token, element_klass)
        super(token)
        Parts.initialize(self, element_klass)
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
      def dump = puts "sql create schema"
    end

    class FileCommand < Command
      alias_method :file, :ast
      def path = file.path

      def dump = puts "file #{path}"
    end

    class ExternalCommand < Command
      forward_to :ast, :source

      def dump
        command = ast.kind.downcase
        puts "#{command} #{ast.multiline? ? "..." : source}"
      end
    end

    class CallCommand < Command
    end


    #
    # R E S O U R C E
    #

    # Can be a schema, provide, or function
    class Resource < Node
      forward_to :"ast.ident", :ident, :uid # FIXME Does this work?
      part :block, [Node] # Command|Require
    end

    class Provide < Resource
      def dump = super uid
    end

    class Require < Node
      forward_to :ast, :ident, :uid
      def dump = super uid
    end

    class Phase < Resource
      def dump = dumps uid, @nodes
    end

    class Function < Resource
    end

    # TODO: End-of-schema-marker (or use schema itself - like other resources)
    class Schema < Resource
      part :head, Command
      part :functions, [Function]
      Token::PHASES.each { |phase| part phase.downcase, Phase }

      def dump()
        head.dump
        functions.each(&:dump)
        Token::PHASES.each(&:dump)
        block.each(&:dump)
      end
    end

    #
    # P R O G R A M
    #

    class Program < Node
      part :schemas, [Schema]
      def initialize(ast) = super(nil, ast)
      def dump()
        super;
        indent { @schemas.each(&:dump) }
      end
    end

    #
    # U N R E S O L V E D
    #

    class Unresolved < Node
      attr_reader :unresolved # Ast::Reference
      def uid = unresolved.uid

      def initialize(prev, ast, unresolved)
        constrain unresolved, Ast::Reference
        super prev, ast
        @unresolved = unresolved
      end

      def dump() = super(uid)
    end
  end
end

