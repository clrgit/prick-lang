module Prick::Lang
  # TODO:
  #   * 'make A.seed' should trigger detect meta in an incremental fashion
  #   * Any seed phase should rebuild the seed of dependent schemas (or what)
  #   * The seed phase is global for all preserved and built schemas
  #     (invalidated schemas are ignored). Seed data are deleted before the
  #     seed phase
  #   * TODO: Should collect all fox statements in the seed phase

  class Generator < CompilerProcess
    # Map from phase kind to attr_reader method
    CATEGORIES = Idr::Phase::PHASES.map { |kind, (rd,wr)| [kind, "#{rd}_units".to_sym] }.to_h

    # Generated units
    attr_reader :units # [Unit]. Initialized by #generate

    # Generated schemas. These schemas are reset and then defined
    attr_reader :build_schemas

    # Schemas that are defined but not rebuilt and not invalid
    attr_reader :preserve_schemas

    # Invalidated schemas. These schemas depends on #schemas but are not
    # themselves rebuilt
    attr_reader :invalidate_schemas

    # Units by phase
    attr_reader :init_units
    attr_reader :this_units
    attr_reader :term_units
    attr_reader :seed_units
    attr_reader :auth_units
    attr_reader :merge_units

    def initialize
      @units = []
      CATEGORIES.values.each { self.instance_variable_set(:"@#{_1}", []) } # initialize *_units variables
    end

    def generate
      nodes = analyzer.reachable_nodes

      # Build graph
      @graph = nodes.map { |node| [node, node.deps] }.to_h

      # Sort nodes
      tsorted_nodes = topological_sort

      # Select nodes for the current compiler mode (:build/:make)
      selected_nodes = tsorted_nodes.select { _1.send(mode_method) }

      # Find schemas to rebuild
      @build_schemas = selected_nodes.map(&:schema).compact.uniq.reject(&:program?)

      # Find schemas depending on rebuild schemas but not included by them
      @invalidate_schemas = find_invalid_schemas

      # Find preserved schemas
      @preserve_schemas = idr.schemas - @build_schemas - @invalidate_schemas

      # Build units
      @units = build_units selected_nodes

      # Sort units into phases. This initializes the #*_units attributes
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

    def dump
      puts "Preserve schemas"; indent {
        preserve_schemas.each &:dumpunit
      }
      puts "Build schemas"; indent {
        build_schemas.each &:dumpunit
      }
      puts "Invalidate schemas"; indent {
        invalidate_schemas.each &:dumpunit
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

    def find_invalid_schemas
      transitive_closure(build_schemas, &:schema_reqs) - build_schemas
    end

    def build_units(nodes)
      units = []
      nodes.each { |node|
        case node
          when Idr::MarkCommand
            units << Unit::Mark.new(node)
          when Idr::MetaCommand
            units << Unit::Meta.new(node)
          when Idr::DetectMetaCommand
            units << Unit::DetectMeta.new(node)
          when Idr::NopCommand
            ;
          when Idr::Command
            units << Unit::Command.new(node)
          when Idr::Phase
            ;
          when Idr::Resource
            ;
        else
          raise
        end
      }
      units
    end

    def transitive_closure(nodes, &block)
      queue = nodes.dup
      seen = Set.new
      while node = queue.shift
        seen << node
        queue.concat yield(node)
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
#     @graph.each_value { |deps| deps.reject(&:exclude).each { |v| in_degree[v] += 1 } }
      @graph.each_value { |deps| deps.each { |v| in_degree[v] += 1 } }
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

      # FIXME FIXME FIXME WTF?
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
        if unit.phase
          attr = CATEGORIES[unit.phase]
          self.send(attr) << unit
        end
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
    #   When we build something, the target's level (init/self/seed/final/auth/merge)
    #   propagates to required objects. Eg. if a require b and we build the
    #   self phase of a previously compiled self phase of b is enough to
    #   satisfy the requirement
    #
    #   Should generate a .prick.completed.yml file with the format
    #
    #     - schema:
    #         name: my_schema
    #         phase: init|self|seed|final|auth|merge|property
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

