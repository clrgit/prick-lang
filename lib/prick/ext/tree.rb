
module Tree
  attr_reader :parent
  attr_reader :children

# forward_to :children, :empty?
  def empty? = children.empty?

  def self.initialize(this, parent = nil)
    @parent = parent && parent.attach(this)
    this.instance_variable_set(:@children, [])
  end

  # Fix this
  #   attach(parent)
  #   detach()
  #   retach(parent)

  def attach(child) @children << child; child.instance_variable_set(:@parent, self) end
  def detach(child) = @children.delete(child)&.instance_variable_set(:@parent, nil)
  def retach(child) child.parent&.detach(child); attach(child) end

  def retach(*children)
    children = Array(children).flatten
    return if children.empty?
    other = children.first.parent
    other.instance_variable_set(:"@children", other.children - children)
    children.each { |child| child.instance_variable_set(:"@parent", self) }
    @children.concat(children)
  end


  def transfer(tree)
    @children = @children.concat tree.children
    tree.children.each { |child| child.instance_variable_set(:@parent, self) }
    tree.instance_variable_set(:@children, [])
  end

# def detach(child = nil)
#   child ? @children.delete(child)&.instance_variable_set(:@parent, nil) : parent.detach(self)
# end
# def retach(parent) self.detach; parent.attach(self) end

  def concat(nodes) nodes.each { attach _1 }; self end
  def move(nodes) nodes.each { retach _1 }; self end

  def assign(attr, child)
    var = :"@#{attr}"
    detach(child) if self.instance_variable_get(var)
    attach(child) if child
    self.instance_variable_set(var, child)
  end

  def upfind(&block)
    return self if yield(self)
    parent&.upfind(&block)
  end


  def each(&block)
    yield(self)
    @children.each { |node| node.each(&block) }
  end

  def map(&block)
    a = []
    self.each { |node| a << yield(node) }
    a
  end

  def pairs(*klass, &expr)
    acc = []
    pairs_impl(acc, klass_expr(klass), nil, &expr)
    acc
  end

  # Return subtrees of any of the given classes and for which expr yields true
  # (the default). All classes are considered by default
  def trees(*klass, &expr)
    klasses = klass_expr(klass)
    acc = []
    @children.each { |node| node.trees_impl(acc, klasses, &expr) }
    acc
  end

  # Return nodes of any of the given classes and for which expr yields true.
  # The expression defaults to true and all classes are considered by default
  def nodes(*klass, &expr)
    klasses = klass_expr(klass)
    acc = []
    self.nodes_impl(acc, klasses, &expr)
#   @children.each { |node| node.nodes_impl(acc, klasses, &expr) }
    acc
  end

# def trees(*klass, &expr) = trees_recursively([], klass_expr(klass), &expr)
# def nodes(*klass, &expr) = nodes_recursively([], klass_expr(klass), &expr)
# def trees(*klass, &expr) = @children.flat_map { _1.trees_recursively([], klass_expr(klass), &expr) }
# def nodes(*klass, &expr) = @children.flat_map { nodes_recursively([], klass_expr(klass), &expr) }

  # Like #nodes but stop iteration when the block returns false
  def visit(*klass, &block) = visit_recursively(klass_expr(klass), &block)

  # bottom-up
  def accumulate(&block)
    yield @children.map { _1.accumulate &block }
  end

  # top-down
  def propagate(&block)
    children.each { _1.propagate &block } if yield(self)
  end


#private
  def klass_expr(klasses) = klasses.empty? ? [Tree] : klasses.flatten

# def pairs_impl(acc) nodes.map { |
#
#   @children.each { |node|
#     acc << [self, node]
#     node.pairs_impl(acc)
#   }
# end

  def pairs_impl(acc, klasses, parent, &expr)
    if klasses.any? { self.class <= _1 } && (block_given? ? expr.call(self) : true)
      acc << [parent, self]
      parent = self
    end
    @children.each { _1.pairs_impl(acc, klasses, parent, &expr) }
  end

  def trees_impl(acc, klasses, &expr)
    if klasses.any? { self.class <= _1 } && (block_given? ? expr.call(self) : true)
      acc << self
    else
      @children.each { |node| node.trees_impl(acc, klasses, &expr) }
    end
  end

  def nodes_impl(acc, klasses, &expr)
    if klasses.any? { self.class <= _1 } && (block_given? ? expr.call(self) : true)
      acc << self
    end
    @children.each { |node| node.nodes_impl(acc, klasses, &expr) }
  end

  def visit_recursively(klasses, &block)
    (klasses.any? { self.class <= _1 } ? yield(self) : true) and
      @children.each { _1.visit_recursively(klasses, &block) }
  end
end

