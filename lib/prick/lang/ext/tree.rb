
module Tree
  attr_reader :parent
  attr_reader :children

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
end

