module Prick::Lang
  # TODO:
  #   * 'make A.seed' should trigger detect meta in an incremental fashion
  #   * Any seed phase should rebuild the seed of dependent schemas (or what)
  #   * The seed phase is global for all preserved and built schemas
  #     (invalidated schemas are ignored). Seed data are deleted before the
  #     seed phase
  #   * TODO: Should collect all fox statements in the seed phase

  class Generator < CompilerProcess
    # Unit phases. This is the phases from the Idr plus an initial setup phase
    # that is used to create/drop schemas
    PHASES = [:SETUP] + Idr::Phase::KINDS

    # Units by phase in dependency order
    attr_reader :phases # {:PHASE=>[Unit]}

    # All units in execution order
    attr_reader :units # [Unit]

    # Generated schemas. These schemas are reset and then redefined
    attr_reader :build_schemas # [Schema]

    # Schemas that are defined but not rebuilt and not invalid
    attr_reader :preserve_schemas # [Schema]

    # Invalidated schemas. These schemas depends on #schemas but are not
    # themselves rebuilt
    attr_reader :invalidate_schemas # [Schema]

    def initialize
    end

    def generate
      nodes = analyzer.reachable_nodes

      # Build graph
      @graph = nodes.map { |node| [node, node.deps] }.to_h

      # Sort nodes
      tsorted_nodes = topological_sort

      # Select nodes for the current compiler mode (:build/:make)
      selected_nodes = tsorted_nodes.select { _1.send(mode_method) }

      # Build units and assign to phases. Initializes @units and @phases
      build_units selected_nodes

      # Find schemas to rebuild
      @build_schemas = selected_nodes.map(&:schema).compact.uniq.reject(&:program?)

      # Find schemas depending on rebuild schemas but not included by them
      @invalidate_schemas = find_invalid_schemas

      # Find preserved schemas
      @preserve_schemas = idr.schemas - @build_schemas - @invalidate_schemas

      # Define setup phase
      initialize_setup_phase

      # Join phases in execution order
      assign_units
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
        puts preserve_schemas.map(&:ident)
      }
      puts "Build schemas"; indent {
        puts build_schemas.map(&:ident)
      }
      puts "Invalidate schemas"; indent {
        puts invalidate_schemas.map(&:ident)
      }
      puts "Phases"; indent {
        for phase in PHASES
          puts phase; indent {
            @phases[phase].each &:dump
          }
        end
      }
      puts "Units"; indent {
        units.each(&:dump)
      }
    end

  private
    attr_reader :graph # {Node=>[Node]} Hash from node to list of dependencies

    def find_invalid_schemas
      transitive_closure(build_schemas, &:schema_reqs) - build_schemas
    end

    # Note that nodes are sorted in dependency order but may straddle phase
    # boundaries
    def build_units(nodes)
      @phases = PHASES.map { |kind| [kind, []] }.to_h
      unit_classes = { SQL: Unit::Sql, PSQL: Unit::PSql, FOX: Unit::Fox, RB: Unit::Ruby }
      nodes.each { |node|
        unit =
            case node
              when Idr::FileCommand
                unit_classes[node.kind].new(node.path)
              when Idr::SqlCommand
                Unit::Sql.new node.source
              when Idr::ExternalCommand
                Unit::Bash.new node.kind, node.source
              when Idr::CallCommand
                Unit::Call.new node.procs
              when Idr::DetectMetaCommand
                Unit::DetectMeta.new
              when Idr::TailCommand
                Unit::Mark.new node.uid
              when Idr::MetaCommand
                Unit::Meta.new node.table
              when Idr::CopyCommand
                Unit::Copy.new node.tables
              when Idr::SyncCommand
                Unit::Sync.new node.table, node.key, node.id_table, node.source.value
              when Idr::PrepareCommand
                Unit::Sync.new node.table, node.key, node.id_table, node.source.value
              when Idr::HandleCommand
                Unit::Handle.new node.tables
              when Idr::NopCommand, Idr::Phase, Idr::Resource
                next
            else
              raise ArgumentError
            end
        @phases[node.phase] << unit
      }
    end

    # Invalidate should
    #   drop the schema
    #   clear its entries in prick.* tables
    #


    def invalidate_schema
    end

    def initialize_setup_phase
      phase = @phases[:SETUP]
      phase.concat \
          @invalidate_schemas.map { |schema| Unit::Db.new(schema, :drop) },
          @build_schemas.map { |schema| Unit::Db.new(schema, :recreate) }
    end

    def assign_units
      current_schema = nil
      @units = []
      PHASES.each { |kind|
        @phases[kind].each { |unit|
#         if unit.is_a?(Unit::IdrNode)
          if !unit.is_a? Unit::Db # FIXME
            this_schema = unit.node.schema
            if unit.node.require_search_path? && this_schema != current_schema
              @units << Unit::SearchPath.new(this_schema) if !this_schema.program?
              current_schema = this_schema
            end
            @units << unit
            if unit.node.change_search_path?
              current_schema = nil
            end
          else
            @units << unit
          end
        }
      }.flatten
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

#   def assign_units
#     units.each { |unit|
#       if unit.phase
#         attr = CATEGORIES[unit.phase]
#         self.send(attr) << unit
#       end
#     }
#   end
  end
end

