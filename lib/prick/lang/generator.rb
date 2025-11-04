module Prick::Lang
  class Generator < CompilerProcess
    # Map from phase kind to attr_reader method
    CATEGORIES = Idr::Phase::PHASES.map { |kind, (rd,wr)| [kind, "#{rd}_units".to_sym] }.to_h

    # Generated units
    attr_reader :units # [Unit]

    # Units by phase
    attr_reader :init_units
    attr_reader :this_units
    attr_reader :seed_units
    attr_reader :term_units
    attr_reader :auth_units
    attr_reader :meta_units # YT

    def nodes = analyzer.reachable_nodes
    def schemas = analyzer.reachable_schemas

    def initialize
      @units = []
      CATEGORIES.values.each { self.instance_variable_set(:"@#{_1}", []) } # assign *_units variables
    end

    def generate
      # Build graph
      @graph = nodes.map { |unit| [unit, unit.deps] }.to_h

      # Sort nodes
      tsorted_nodes = topological_sort

      # Build units
      build_units tsorted_nodes

      # Sort units into phases
      categorize_units

      @units
    end

    # if running-make
    #   completed_nodes = completed_resources.transitive_closure(deps)
    #   dirty_nodes = (make_nodes + updated_files).transitive_closure(uses)
    #   generated_nodes = all_nodes - (completed_nodes - dirty_nodes)
    # end
    #
    # Also mark schemas: Some schemas doesn't have to be rebuilt even if
    # they're not completed

    # Generate
    #   mark dirty using #uses hierarchy if requested
    #   process reachable nodes

    def make
      inverted_graph = nodes.map { |unit| [unit, unit.deps] }.to_h
    end

    def dump
      puts "Schemas"; indent {
        schemas.each &:dumpunit
      }
      puts "Phases"; indent {
        for kind, rd in CATEGORIES
          next if kind == :META
          puts kind; indent {
            self.send(rd).each &:dumpunit
          }
        end
      }
    end

  private
    attr_reader :graph # {Node=>[Node]} Hash from node to list of dependencies

    def build_units(nodes)
      nodes.each { |node|
        case node
          when Idr::MarkCommand
            @units << Unit::Mark.new(node)
          when Idr::NopCommand
            ;
          when Idr::Command
            @units << Unit::Command.new(node)
          when Idr::Resource
            ;
        else
          raise
        end
      }
    end

    def transitive_closure(nodes)
      stack = nodes.map { |uid| compiler.resources[uid] }
      seen = Set.new
      while node = stack.pop
        seen << node
        stack.concat node.deps
      end
      seen.to_a
    end

    def topological_sort
      l = ->(node) {
        case node
          when Idr::FileCommand
            node.ast.extname
          when Idr::ExternalCommand
            "<external>"
          else
            true
        end
      }
      grouped_topological_sort(group_by: l)
    end

    # graph is a hash from node to list of its dependencies {Node: [Node]}
    def grouped_topological_sort(group_by: ->(n) { true })
      in_degree = Hash.new(0)
      @graph.each_value { |deps| deps.reject(&:exclude).each { |v| in_degree[v] += 1 } }
      in_degree.default = 0

      # Start with nodes that have no incoming edges
      ready = @graph.keys.select { |k| in_degree[k].zero? }

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

#       # group and sort by group key
#       grouped = ready.group_by(&group_by).tap { p _1 }.sort_by(&:first)
#       node = grouped.first[1].shift
#       node = ready.group_by(&group_by).sort_by(&:first).first[1].first

        ready.delete(node)
        result << node

        @graph[node].each do |child|
          in_degree[child] -= 1
          ready << child if in_degree[child].zero?
        end
      end

      if result.size != @graph.keys.size
        puts "result: #{result.map(&:serial)}"; indent {
          result.each(&:dumpline)
        }
        puts "keys: #{@graph.keys.map(&:serial)}"; indent {
          @graph.keys.each { |node|
            node.dumpline
          }
        }

        raise "Graph has a cycle"
      end

      result.reverse
    end

    def categorize_units
      units.each { |unit|
        attr = CATEGORIES[unit.phase]
        self.send(attr) << unit
      }
    end
  end
end

__END__

    # Create schema command should be moved to the start
    # The executor should handle schemas

    # TODO: All links should refer to completion nodes (or provides)
    #
    # TODO
    #   Understand layered build
    #     program init
    #     all init
    #     all self
    #     all seed
    #     all final
    #     program self
    #     program seed
    #     program final
    #     all auth
    #     program auth
    #
    #   When we build something, the target's level (init/self/seed/final/auth)
    #   propagates to required objects. Eg. if a require b and we build the
    #   self phase of a previously compiled self phase of b is enough to
    #   satisfy the requirement
    #
    #   Should generate a .prick.completed.yml file with the format
    #
    #     - schema:
    #         name: my_schema
    #         phase: init|self|seed|final|auth|property
    #
    #   The executor can reuse a whole schema or continue compiling from a
    #   property but when an error happens, the entire schema is invalidated
    #
    #   Q: How to elimitate nodes when continuing from a property?
    #   A: Use the transitive closure
    #
    #   N: The executer should control the generator because it determines which
    #   targets should be rebuilt when running 'prick make'. The state of the
    #   last compilation is read from .prick.completed.yml and the transitive
    #   closuere of completed targets are eliminated from the build set
    #     N: No. We read .prick.completed.yml from the compiler and feeds it into
    #        #generate using the :exclude argument
    #     N: The compiler should then also detect changed files when running
    #        'prick make'
    #
    #   N: Schemas are also be invalidated when a .prick file or any referred
    #   file changes
    #
    #   N: We need to know all files involved
    #
    #   P: We need a 'make' command to be able to update auto-generated files
    #     N: We can revert to 'prick build' when an auto-generated file changes
    #

