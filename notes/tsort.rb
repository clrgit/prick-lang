#!/usr/bin/env ruby

require 'indented_io'
require 'tsort'

class Graph
  include TSort

  def initialize(edges)
    @edges = edges
  end

  def tsort_each_node(&block)
    @edges.each_key(&block)
  end

  def tsort_each_child(node, &block)
    @edges[node].each(&block)
  end
end

def grouped_toposort(graph, group_by:)
  in_degree = Hash.new(0)
  graph.each_value { |deps| deps.each { |v| in_degree[v] += 1 } }
  in_degree.default = 0

  # Start with nodes that have no incoming edges
  ready = graph.keys.select { |k| in_degree[k].zero? }

  result = []
  while ready.any?
    # Choose from the best group
    grouped = ready.group_by(&group_by)
    sorted_keys = grouped.keys.sort_by { |l,r|
      case [l || false, r || false]
        in [false, false]; 0
        in [true, false]; 1
        in [false, true]; -1
        in [true, true]; 0
        else -1
      end
    }
    best_group_key = sorted_keys.first
    node = grouped[best_group_key].first


    # group and sort by group key
#   grouped = ready.group_by(&group_by).tap { p _1 }.sort_by(&:first)
#   node = grouped.first[1].shift
#   node = ready.group_by(&group_by).sort_by(&:first).first[1].first

    ready.delete(node)
    result << node

    graph[node].each do |child|
      in_degree[child] -= 1
      ready << child if in_degree[child].zero?
    end
  end

  if result.size != graph.keys.size
    raise "Graph has a cycle"
  end

  result
end


# a
#   B
#   c
#     D
#       h
#   e
#     F
#       g
#       h
#   h
#     I
#

# g F D B e c a


graph = {
  a: [:B, :c, :e],
  B: [],
  c: [:D, :h],
  D: [],
  e: [:F],
  F: [:g, :h],
  g: [],
  h: [:I],
  I: []
}

# B D c g F e a
# g B D F c e a


grouped = grouped_toposort(graph, group_by: ->(n) { [:B, :D, :F, :I].include? n })
puts "---------------------------------"
p grouped






__END__

#edges = {
# :a => [:b],
# :b => [:c],
# :c => [],
# :d => [:b],
# :e => [:c]
#}

g = Graph.new(edges)
sorted = g.tsort  # => [:a, :d, :e, :b, :c]
p sorted
exit

# assume grouping by first letter or some property
groups = sorted.group_by { |node| [:B, :D, :F].include? node }

# flatten groups in order of first appearance
grouped = groups.keys.flat_map do |key|
  group = groups[key]
  # keep stable order within group
  group.sort_by { |n| sorted.index(n) }
end

p grouped  # still topologically sorted, but grouped




