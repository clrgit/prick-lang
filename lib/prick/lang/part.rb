module Prick::Lang
  module Ast
    class Part
      include Tree

      # Map from class to array of [sym, klass, element klass] tuples, one for
      # each part object
      @@PARTS = {}

      # :call-seq:
      #   part ident, klass = Part
      #   part ident, [klass]
      #
      # Register a part object
      #
      def self.part(sym, constraint = Part)
        constrain sym, Symbol
        constrain constraint, Class, [Class]

        attr_reader sym

        element_klass = nil
        if constraint.is_a?(Array)
          klass = Nodes
          element_klass = constraint.first
          define_method(:"#{sym}=") { |node|
            if node.nil?
              assign(sym, nil)
            else
              if node.is_a? Nodes
                node.nil? || node.is_a?(Nodes) or
                    raise ArgumentError, "Expected a Nodes object, got #{node.class}"
                node.nil? || node.element_klass < element_klass or
                    raise ArgumentError, "Expected a Nodes of #{element_klass} objects, " +
                                         "got Nodes of #{node.element_klass}"
                assign(sym, node)

              elsif node.is_a? Array
                nodes = Nodes.new(nil, element_klass)
                nodes.concat node
                assign(sym, nodes)

              else
                raise ArgumentError, "Expected #{element_klass} objects, got #{node.class}"
              end
            end
            self
          }
        else
          klass = constraint
          define_method(:"#{sym}=") { |node|
            node.is_a?(klass) or
                raise ArgumentError, "Expected #{klass} object, got #{node.class}"
            self.assign(sym, node)
          }
        end

        (@@PARTS[self] ||= []) << [sym, klass, element_klass]
      end

      def get_part(sym) = self.instance_variable_get(:"@#{sym}")

      def initialize
        # Assign [] to Nodes objects
        for sym, klass, element_klass in @@PARTS[self.class] || []
          if klass == Nodes
            if get_part(sym).nil?
              assign(sym, Nodes.new(nil, element_klass))
            end
          end
        end
      end
    end
  end
end

