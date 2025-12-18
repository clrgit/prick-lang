
module Prick::Lang
  module Unit
    class Node
      attr_reader :node # IdrNode
      def phase = node.parent.kind

      def initialize(node, exclude = false)
        constrain node, Idr::Node
        @node = node
      end

      def dumpunit
#       print "#{phase} "
        node.dumpunit
      end

      def dumpline = node.dump
      def dumpdep = node.dump
      def dump = dumpline
#     def dump = puts "#{phase} #{node.token.kind} #{node.token.text}"
      def dump = puts "#{node.token.kind} #{node.token.text}"
    end

    class SearchPath < Node
      def dumpline = puts "set search_path to '#{node.schema.ident || "public"}'"
      def dumpdep = puts "set search_path to '#{node.schema.ident || "public"}'"
    end

    class Command < Node
      def is_schema_command? = node.is_a?(Idr::SchemaCommand)

      def dumpunit
        case node
          when Idr::MarkCommand; node.dumpline
          else super
        end
      end
    end

    class Mark < Node
      forward_to :node, :kind

      def initialize(node, **opts)
        constrain node, Idr::MarkCommand
        super(node, **opts)
      end
      def dumpunit = node.dumpline
    end

    class Meta < Node
      def dumpunit = node.dumpline
    end

    class DetectMeta < Node
      def dumpunit = node.dumpline
    end
  end
end

