module Prick::Lang
  module Ast
    # Acts as a trimmed-down Array of Part objects
    module Parts
      attr_reader :element_klass
      forward_to :@children, :each, :map, :empty?

      def self.initialize(this, element_klass)
        this.instance_variable_set(:@element_klass, element_klass)
      end

      def replace(parts)
#       puts "Parts#replace(#{parts.inspect}) #{self.class}"
        parts.each { |part|
          part.is_a?(element_klass) or unexpected_error element_klass, part
        }
        @children = parts
      end

      # TODO Remove?
      def <<(node)
        !node.nil? or raise ArgumentError
        node.is_a? element_klass or unexpected_error element_klass, node
        @children << node
      end

      def build_tree
#       puts "#{self.classname}#build_tree"
        @children.each { |part|
          part.build_tree
          part.instance_variable_set(:@parent, self)
#         part.instance_variable_set(:@parent, self.parent)
        }
      end
    end

    class Part
      include ErrorFunctions
      include Tree

      # Map from class to array of [sym, klass, element klass] tuples, one for
      # each part object. #self.inherited guarantees that @@PARTS will never be
      # nil for a class derived from Part
      @@PARTS = { Part => [] }

      # :call-seq:
      #   part ident, klass = Part
      #   part ident, [klass]
      #
      # Register a part object
      #
      def self.part(sym, constraint = Part)
        constrain sym, Symbol
        constrain constraint, Class, [Class]

        method = :"#{sym}="
        member = :"@#{sym}"

        if constraint.is_a?(Array)
          klass = Nodes
          element_klass = constraint.first

          define_method(sym) { get_part(sym).children }

          define_method(method) { |nodes|
            case nodes
              when Array; get_part(sym).replace nodes
              when Nodes; get_part(sym).replace nodes.children
            else
              unexpected_error(element_klass, node)
            end
          }
        else
          klass = constraint
          element_klass = nil
          attr_reader sym
          define_method(method) { |node|
            node.is_a?(klass) or unexpected_error klass, node
            self.instance_variable_set(member, node)
          }
        end

        (@@PARTS[self] ||= []) << [sym, klass, element_klass]
      end

      def self.parts() = @@PARTS[self]
      def get_part(sym) = self.instance_variable_get(:"@#{sym}")

      def initialize
#       puts "Part#initialize #{self.class.classname}"
        # Create Nodes part objects
        for sym, klass, element_klass in @@PARTS[self.class]
          if klass == Nodes
            if get_part(sym).nil?
              self.instance_variable_set(:"@#{sym}", Nodes.new(nil, element_klass))
            end
          end
        end
      end

      def self.inherited(subklass)
        @@PARTS[subklass] = (@@PARTS[self] ||= []).dup
      end

      def build_tree
#       puts "#{self.classname}#build_tree"
        for sym, klass, element_klass in @@PARTS[self.class] || []
          part = get_part(sym) or next
          part.build_tree
          attach(part)
        end
      end
    end
  end
end

__END__

      def self.part0(sym, constraint = Part)
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

