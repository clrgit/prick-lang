module Graph
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
end

