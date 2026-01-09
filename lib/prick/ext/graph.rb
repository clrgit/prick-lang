module Graph

  #
  # T R A N S I T I V E   C L O S U R E
  #

  def self.transitive_closure(nodes, &block)
    queue = nodes.dup
    seen = Set.new
    while node = queue.shift
      seen << node
      queue.concat yield(node)
    end
    seen.to_a
  end

  def transitive_closure(nodes, &block) = Graph.transitive_closure nodes, &block

  # 
  # T R A V E R S E R
  #

  # Common class for MethodTraverser and ArrayTraverser
  class Traverser
    attr_reader :payload_block
    attr_reader :traverse_block

    def initialize(payload_block, traverse_block)
      @payload_block = payload_block
      @traverse_block = traverse_block
    end
  end

  class MethodTraverser < Traverser
    attr_reader :stack
    attr_reader :method

    def initialize(method, payload_block)
      @stack = []
      @method = method
      traverse_block = lambda {
        nodes = @stack.last.send(method)
        nodes.each { |node|
          @stack.push node
          payload_block.call(node, traverse_block)
          @stack.pop
        }
      }
      super(payload_block, traverse_block)
    end
  end

  class ArrayTraverser < Traverser
    def initialize(payload_block)
      traverse_block = lambda { |nodes|
        nodes.each { |node|
          payload_block.call(node, traverse_block)
        }
      }
      super(payload_block, traverse_block)
    end
  end

  # :call-seq:
  #   Graph.traverse(node) do |node, traverser| ... traverser.call nodes ... end
  #   Graph.traverse(node, method) do |node, traverser| ... traverser.call ... end
  #
  def self.traverse(node, method = nil, &payload_block)
    if method
      traverser = MethodTraverser.new(method, payload_block)
      traverser.stack.push node
      payload_block.call(node, traverser.traverse_block)
      traverser.stack.pop
    else
      traverser = ArrayTraverser.new(payload_block)
      payload_block.call(node, traverser.traverse_block)
    end
  end

  # :call-seq:
  #   traverse(node) do |node, traverser| ... traverser.call nodes ... end
  #   traverse(node, method) do |node, traverser| ... traverser.call ... end
  #
  def traverse(node, method = nil, &payload_block) = Graph.traverse(node, method, payload_block)
end

