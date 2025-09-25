
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

  def trees(*klass, &expr)
    klasses = klass_expr(klass)
    acc = []
    @children.each { |node| node.trees_impl(acc, klasses, &expr) }
    acc
  end

  def nodes(*klass, &expr)
    klasses = klass_expr(klass)
    acc = []
    @children.each { |node| node.nodes_impl(acc, klasses, &expr) }
    acc
  end

# def trees(*klass, &expr) = trees_recursively([], klass_expr(klass), &expr)
# def nodes(*klass, &expr) = nodes_recursively([], klass_expr(klass), &expr)
# def trees(*klass, &expr) = @children.flat_map { _1.trees_recursively([], klass_expr(klass), &expr) }
# def nodes(*klass, &expr) = @children.flat_map { nodes_recursively([], klass_expr(klass), &expr) }
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
  def klass_expr(klasses) = klasses.empty? ? [Tree] : klasses

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

