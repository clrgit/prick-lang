
module Prick::Lang
  module Idr
    class Node
      def self.classname = self.to_s.sub(/.*::/, "")
      def classname = self.class.classname

      attr_accessor :prev # Node. Previous node. May be nil
      attr_reader :ast # Ast::Node
      def token = ast.token
      attr_reader :deps # Node. Dependencies in addition to #prev. In reality either one or none object

      def initialize(prev, ast)
        @prev = prev
        @ast = ast
      end

      def dump(*text) = dump_impl(*text)
      def dumps(*text, nodes) dump_impl(*text); indent { nodes.each &:dump } end

      def inspect = "<#{self.classname}>"

    private
      # To avoid endless recursion when #dump is redefined
      def dump_impl(*text) = puts ([self.classname] + text).compact.join(" ")
    end

    class Program < Node
      attr_accessor :schemas
      def dump()
        super;
        indent { @schemas.each(&:dump) }
      end
    end

    # Can be a schema, provide, or function
    class Resource < Node
      forward_to :"ast.ident", :ident, :uid # FIXME Does this work?
    end

    # TODO: End-of-schema-marker (or use schema itself - like other resources)
    class Schema < Resource
      attr_accessor :nodes # [Node]
      attr_accessor :head # Entry node, only used by Schema. Embedded objects depend on head. FIXME: They do?
      def tail() = nodes.last # Last node. External objects depend on tail. Equal to :head for simple objects
      attr_accessor :functions # {uid=>Function}
      attr_accessor :init, :term, :meta, :seed, :auth # Phase

      def dump() = dumps @nodes
    end

    class Provide < Resource
      def dump = super uid
    end

    class Require < Node
      forward_to :ast, :ident, :uid
      def dump = super uid
    end

    class Phase < Node
      def ident = ast.ident.value
      def uid = ast.ident.uid
      attr_accessor :nodes
      def dump = dumps uid, @nodes
    end

    class Command < Node
      attr_accessor :kind
      def is_referenced?() = raise
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

