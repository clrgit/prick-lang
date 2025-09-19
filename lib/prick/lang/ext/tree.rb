
module Tree
  attr_reader :parent
  attr_reader :children

  forward_to :children, :empty?

  def self.initialize(this, parent = nil)
    @parent = parent && parent.attach(this)
    this.instance_variable_set(:@children, [])
  end

  def attach(child) @children << child; child.instance_variable_set(:@parent, self) end
  def detach(child)
    @children.delete(child)
    child&.instance_variable_set(:@parent, nil)
  end
  def retach(child) child.parent&.detach(child); attach(child) end

  def concat(nodes) nodes.each { attach _1 }; self end
  def move(nodes) nodes.each { retach _1 }; self end

  def assign(attr, child)
    var = :"@#{attr}"
    detach(child) if self.instance_variable_get(var)
    attach(child) if child
    self.instance_variable_set(var, child)
    self
  end

  def each(&block)
    yield(self)
    @children.each { |node| node.each(&block) }
  end

  def map(&block)
    a = []
    each { |node| a << yield(node) }
    a
  end

  def trees(*klass, &expr) = trees_recursively([], klass, &expr)
  def nodes(*klass, &expr) = nodes_recursively([], klass, &expr)
  def visit(*klass, &block) = visit_recursively(klass, &block)

#   klasses = [Object] if expr.empty?
#   visit_recursively(klasses, &block)
#   (expr.include?(self.class) ? yield(self) : true) and @children.each { _1.visit(expr, &block) }
#   (self.is_a?(klass) ? yield(self) : true) and @children.each { _1.visit(klass, &block) }
# end

  # bottom-up
  def accumulate(&block)
    yield @children.map { _1.accumulate &block }
  end

  # top-down
  def propagate(&block)
    children.each { _1.propagate &block } if yield(self)
  end

#private
  def trees_recursively(trees, klasses, &expr)
    if klasses.include?(self.class) && (block_given? ? expr.call(self) : true)
      trees << self
    else
      @children.each { |node| node.trees_recursively(trees, klasses, &expr) }
    end
    trees
  end

  def nodes_recursively(nodes, klasses, &expr)
    if klasses.include?(self.class) && (block_given? ? expr.call(self) : true)
      nodes << self
    end
    @children.each { |node| node.nodes_recursively(nodes, klasses, &expr) }
    nodes
  end

  def visit_recursively(klasses, &block)
    (klasses.include?(self.class) ? yield(self) : true) and @children.each { _1.visit_recursively(klasses, &block) }
  end
end

