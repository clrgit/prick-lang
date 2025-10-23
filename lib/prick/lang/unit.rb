
module Prick::Lang
  module Unit
    class Node
      attr_reader :node # IdrNode

      def initialize(node, exclude = false)
        constrain node, Idr::Node
        @node = node
      end

      def dumpunit = node.dumpunit

      def dumpline = node.dump
      def dumpdep = node.dump
      def dump = dumpline
      def dump = puts "#{node.token.kind} #{node.token.text}"
    end

    class SearchPath < Node
      def dumpline = puts "set search_path to '#{node.schema.ident || "public"}'"
      def dumpdep = puts "set search_path to '#{node.schema.ident || "public"}'"
    end

    class Command < Node
      def is_schema_command? = node.is_a?(Idr::SchemaCommand)
    end

    # Resource nodes are created but later removed because they only serves as
    # anchors
    class Resource < Node
    end
  end
end
