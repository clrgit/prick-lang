
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

      def dump(*text) = dump_impl(*text)
      def dumps(*text, nodes) dump_impl(*text); indent { nodes.each &:dump } end

      def inspect = "<#{self.classname}>"

    private
      # To avoid endless recursion when #dump is redefined
      def dump_impl(*text) = puts ([self.classname] + text).compact.join(" ")
    end

    class Nodes < Node
      include Parts

      # #ast is initially nil butand then redefined to the ast of the first node
      def ast = @ast || children.first&.ast

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

    # Can be a schema, phase, provide, or function
    class Resource < Node
      forward_to :ast, :ident
      alias_method :schema, :parent
      attr_reader :uid
      part :block, [Node] # Command|Require
      def initialize(ast, uid)
        super(ast)
        @uid = uid
      end
    end

    class Phase < Resource
      def dump = dumps uid, @block
    end

    class Provide < Resource
      def dump = super uid
    end

    class Function < Resource
    end

    # TODO: End-of-schema-marker (or use schema itself - like other resources)
    class Schema < Resource
      def schema = nil
      part :head, Command
      part :functions, [Function]
      Token::PHASES.each { |phase| part phase.downcase, Phase }
      def provides() = nil # TODO

      def dump()
        puts "Schema #{ident}"
        indent {
          puts "head"; indent {
            head.dump
          }
          puts "functions"; indent {
            functions.each(&:dump)
          }
          puts "phases"; indent {
            Token::PHASES.each { |phase|
              ident = phase.downcase.to_sym
              if !parts[ident].nil?
                parts[ident].dump
              end
            }
          }
          puts "block"; indent {
            block.each(&:dump)
          }
        }
      end
    end

    #
    # P R O G R A M
    #

    class Program < Schema
      part :schemas, [Schema]
      def dump()
        super
        indent { @schemas.each(&:dump) }
      end
    end

    #
    # R E Q U I R E
    #
    class Require < Node
      alias_method :schema, :parent
      attr_reader :uid
      attr_accessor :node # Required entry node
      def initialize(ast, uid)
        constrain ast, Ast::Reference
        super(ast)
        @uid = uid
      end
      def dump
        txt = uid
        txt += " -> #{node.class}" if node
        super txt
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

      def dump() = super(uid)
    end
  end
end


