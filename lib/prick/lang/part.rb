module Prick::Lang
    # Acts as a trimmed-down Array of Part objects
    module Parts
      attr_reader :element_klass
      forward_to :@children, :each, :map, :empty?

      def self.initialize(this, element_klass)
        this.instance_variable_set(:@element_klass, element_klass)
      end

      def self.included?(mod)

      end

      def replace(parts)
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

      # Map from class to array of [sym, klass, element klass] tuples - one for
      # each part object. #self.inherited guarantees that @@PARTS will never be
      # nil for a class derived from Part
      @@PARTS = { Part => [] }


      # The class that derivv
      @@ROOT_CLASS = nil

      # Map from @@ROOT_PART class
      @@ARRAY_PART = nil



#     def self.root_class = @@ROOT_PART[

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
        Tree.initialize(self)
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
