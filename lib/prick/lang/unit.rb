
module Prick::Lang
  module Unit
    class Node
      include ClassFunctions
    end

    class SetupCommand < Node

    end

    class SchemaCommand < SetupCommand
      attr_reader :command # :create, :clear, :drop
    end

    class SearchPath < Node
      attr_reader :schema # Idr::Schema
      def initialize(schema) @schema = schema end
    end

    class ClearSchemaSeed < Node
    end

    class DetectMeta < Node
    end

    class IdrNode < Node
      attr_reader :node # Idr::Node
      forward_to :node, :schema, :require_search_path?, :change_search_path?

      def initialize(node)
        constrain node, Idr::Node
        @node = node
      end
    end

    class Command < IdrNode
    end

    # Mark a resource as built by inserting a record in prick.resources. It is
    # generated from tail nodes
    class Mark < IdrNode
      def resource = node.uid
    end

    class Meta < IdrNode
    end
  end
end


