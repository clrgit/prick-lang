
# IDEA
#   Part objects have both a #parts and a #children member method, parts
#   include #children. There should be two sets of tree functions: One for the
#   parts hierarchy and one for the children hierarchy


module Prick::Lang
  # Acts as a trimmed-down Array of Part objects
  module Parts
    attr_reader :element_klass
    forward_to :@children, :first, :last, :each, :map, :flat_map, :empty?, :size, :any?, :all?

    def self.initialize(this, element_klass)
      this.instance_variable_set(:@element_klass, element_klass)
    end

    def replace(parts)
      parts.each { |part|
        part.is_a?(element_klass) or unexpected_error element_klass, part
      }
      @children.dup.each { detach _1 }
      parts.each { attach _1 }
    end

    def <<(node)
      !node.nil? or raise ArgumentError
      node.is_a? element_klass or unexpected_error element_klass, node
      attach(node)
    end

    def self.included(other)
      other.root.define_singleton_method(:array) { other }
    end
  end

  class PartMap
    attr_reader :whole

    def initialize(whole)
      @whole = whole
      @klass = whole.class
    end

    def empty?() = @klass.parts.empty?
    def key?(ident) = @klass.part? ident
    def keys() = @klass.parts.keys
    def values() = @keys.map { whole.send(_1) }

    def each(&block) = keys.each { |ident| yield ident, whole.send(ident) }

    def [](ident)
      @klass.part? ident or
          raise ArgumentError, "Unknown member of #{@klass.classname}: #{ident}"
      @whole.send(ident)
    end

    def []=(ident, value)
      @klass.part? ident or
          raise ArgumentError, "Unknown member of #{whole.classname}: #{ident}"
      @whole.send(:"#{ident}=", value)
    end

    def to_h
      keys.map { |ident| [ident, whole.send(ident)] }.to_h
    end
  end

  class Part
    include ErrorFunctions
    include Tree

    alias_method :whole, :parent # Only valid after #build_tree has run
    attr_reader :parts # PartMap

    def initialize
      # Initialize as a Tree node
      Tree.initialize(self)

      # Setup hash interface to part objects
      @parts = PartMap.new(self)

      # Create array part objects
      for ident, element_klass in @@ARRAY_PARTS[self.class] || []
        next if element_klass.nil?
        if parts[ident].nil?
          self.assign(ident, self.class.array.new(nil, element_klass))
#         attach(array)
#         self.instance_variable_set(:"@#{ident}", array)
        end
      end
    end

    def self.all_parts = @@PARTS

    def self.root? = root() == self
    def self.array? = array() == self
    def self.part?(ident) = @@PARTS[self].key?(ident)
    def self.parts() = @@PARTS[self] # Symbol => Class
    def self.klassname(ident)
      klass = parts[ident]
      if klass == Array
        "[#{@@ARRAY_PARTS[self][ident].classname}]"
      else
        klass.classname
      end
    end

    # :call-seq:
    #   part ident, klass = Part
    #   part ident, [klass]
    #
    # Register a part object and create accessor methods
    #
    def self.part(ident, constraint = Part)
      constrain ident, Symbol
      constrain constraint, Class, [Class]
      constrain Array(constraint).all? { _1 <= Part }, true # Only Part classes can be parts

      method = :"#{ident}="
      member = :"@#{ident}"

      if constraint.is_a?(Array)
#       self.array? or raise ArgumentError, "#{root.classname} does not define an array type"
        klass = self.array
        element_klass = constraint.first

        # Define reader method
        define_method(ident) { self.instance_variable_get(:"@#{ident}") }

        # Define writer method
        define_method(method) { |nodes|
          this = self.instance_variable_get(:"@#{ident}")
          case nodes
            when Array; this.replace nodes
            when Parts; this.replace nodes.children
          else
            unexpected_error("array of #{element_klass.classname}", nodes)
          end
        }
      else
        klass = constraint
        element_klass = nil

        # Define reader method
        attr_reader ident

        # Define writer method
        define_method(method) { |node|
          node.is_a?(klass) or unexpected_error klass, node.class
          self.assign(ident, node)
        }
      end

      # Register part
      @@PARTS[self][ident] = klass
      @@ARRAY_PARTS[self][ident] = element_klass if element_klass
    end

    def self.inherited(klass)
      if self == Part # Only consider top-level classes
        @@PARTS[klass] = {}
        @@ARRAY_PARTS[klass] = {}
        klass.define_singleton_method(:root) { klass }
        klass.define_singleton_method(:array) { nil } # Default implementation. Initialized by M::included
      else
        # Copy parent's attributes
        @@PARTS[klass] = @@PARTS[self].dup
        @@ARRAY_PARTS[klass] = @@ARRAY_PARTS[self].dup
      end
    end

    def self.dump_model
      @@PARTS.each { |part, parts|
        puts part.classname
        indent {
          (@@PARTS[part] || []).each { |ident, klass|
            puts "#{ident} #{klass.classname}"
          }
        }
      }
    end

    # Map from Class to map from Symbol to Class
    @@PARTS = { Part => {} } # { Class => { Symbol => klass }

    # Map from Class to map from attribute to element type. Element type is nil
    # for non-array parts
    @@ARRAY_PARTS = { Part => {} } # { Class => { Symbol => element_klass } }
  end
end

