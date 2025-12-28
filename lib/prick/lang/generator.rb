module Prick::Lang
  # TODO:
  #   * 'make A.seed' should trigger detect meta in an incremental fashion
  #   * Any seed phase should rebuild the seed of dependent schemas (or what)
  #   * The seed phase is global for all preserved and built schemas
  #     (invalidated schemas are ignored). Seed data are deleted before the
  #     seed phase
  #   * TODO: Should collect all fox statements in the seed phase

  # TODO: Rename #unit -> #execute_units and redefine #unit to return all units
  class Generator < CompilerProcess
    # Unit phases. This is the phases from the Idr plus an initial setup phase
    # that is used to create/drop schemas
    PHASES = [:SETUP] + Idr::Phase::KINDS

    # Units initially generated from the Idr. Units that are created later are not
    # included (eg. Unit::Marks)
    attr_reader :units

    # Nodes by unit. Used to lookup the associated node without polluting Unit
    # with compiler objects
    attr_reader :nodes # {Unit => Node}

    # Units and associated node by phase in dependency order. Note that all
    # phases are present even if they have no nodes
    attr_reader :phases # {PHASE=>[Unit::Node]}

#   # Active phases (phases that have nodes that will be built)
#   attr_reader :active_phases # [PHASE]

    # Generated schemas. These schemas are reset and then redefined
    attr_reader :build_schemas # [Schema]

    # Schemas that are defined but not rebuilt and not invalid
    attr_reader :preserve_schemas # [Schema]

    # Invalidated schemas. These schemas depends on #schemas but are not
    # themselves rebuilt
    attr_reader :invalidate_schemas # [Schema]

    # Final set of units in execution order
    attr_reader :execute_units # [Unit]

    def initialize
    end

    def generate
      # Build graph
      @graph = analyzer.reachable_nodes.map { |node| [node, node.deps] }.to_h

      # Sort nodes
      tsorted_nodes = topological_sort

      # Select nodes for the current compiler mode (:build/:make)
      selected_nodes = tsorted_nodes.select { _1.send(mode_method) }

      # Build units and assign to phases. Initializes @execute_units and @phases
      build_units selected_nodes

      # Find schemas to rebuild
      @build_schemas = selected_nodes.map(&:schema).compact.uniq.reject(&:program?)

      # Find schemas depending on rebuild schemas but not included by them
      @invalidate_schemas = find_invalid_schemas

      # Find preserved schemas
      @preserve_schemas = idr.schemas - @build_schemas - @invalidate_schemas

      @execute_units = []

      generate_resource_units

      # Assign initial units (creates/drops schemas) and set up transaction
      generate_initial_units

      # Join phases in execution order
      generate_script_units

      # Assign final units and commit outstanding changes
      generate_final_units
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

#   def dump
#     puts "Preserve schemas"; indent {
#       puts preserve_schemas.map(&:ident)
#     }
#     puts "Build schemas"; indent {
#       puts build_schemas.map(&:ident)
#     }
#     puts "Invalidate schemas"; indent {
#       puts invalidate_schemas.map(&:ident)
#     }
#     puts "Phases"; indent {
#       for phase in PHASES
#         puts phase; indent {
#           @phases[phase].each &:dump
#         }
#       end
#     }
#     puts "Units"; indent {
#       units.each(&:dump)
#     }
#   end

    def inspect = "#<Generator ...>"

  private
    attr_reader :graph # {Node=>[Node]} Hash from node to list of dependencies

    def find_invalid_schemas
      transitive_closure(build_schemas, &:schema_reqs) - build_schemas
    end

    # Note that nodes are sorted in dependency order but may straddle phase
    # boundaries
    def build_units(nodes)
      @phases = PHASES.map { |kind| [kind, []] }.to_h # {PHASE=>[Unit]}
      @units = []
      @nodes = {}
      unit_classes = { SQL: Unit::SqlFile, PSQL: Unit::PSqlFile, FOX: Unit::FoxFile, RB: Unit::RubyFile }
      p node.class
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
                Unit::Mark.new node.phase, node.schema&.ident, node.uid
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
        @units << unit
        @nodes[unit] = node
        @phases[node.phase] << unit
      }
    end

    # Invalidate should
    #   drop the schema
    #   clear its entries in prick.* tables
    #


    def invalidate_schema
    end

    # delete from

    # Generate units to delete resources from PRICK.RESOURCES that will be
    # rebuilt
    def generate_resource_units
#     p dirty_schemas
#     p dirty_phases
#     exit

#     # Global resources (eg. the program-level 'init' phase)
#     phases = Set.new
#     @units.each { |unit|
#       phases.add(unit.phase_name) if unit.is_a?(Unit::Mark) && unit.schema_name.nil?
#     }
#     dirty_phases = phases.to_a
#
#     # Find regular resources from dirty schemas
#     dirty_schemas = (build_schemas + invalidate_schemas
#
#     @execute_units << Unit::DeleteResources.new(dirty_phases, dirty_schemas)
#     exit

    end

    # Drop/reset schemas and delete invalid resources entries
    def generate_initial_units
      # Find dirty schemas. We don't use build_schemas+invalidate_schemas
      # because schemas outside of the build set may be dirty and have to clear
      # its resources
      dirty_schemas = idr.trees(Idr::Schema).select(&:dirty?).map(&:ident)

      # Dirty program phases
      dirty_phases = program.phases.values.select(&:dirty?).map(&:kind)

      # Drop/reset dirty schemas
      @execute_units =
          [ Unit::Transaction.new(:BEGIN),
            Unit::UnMarks.new(dirty_phases, dirty_schemas) ] +
          @invalidate_schemas.map { |schema| Unit::Db.new(schema.ident, :DROP) } +
          @build_schemas.map { |schema| Unit::Db.new(schema.ident, :RESET) } +
          [ Unit::Transaction.new(:COMMIT) ]
    end

    # TODO Add^H^H^H ensure commits and end-of-schema (we already do that?)

    # Flatten phases and insert search path commands
    def generate_script_units
      current_schema = nil
      commit_before = false
      commit_after = false
      current_mark = nil

      # Process phases and build @execute_units array
      PHASES.each { |kind|
        @phases[kind].each { |unit|

          # Collect mark commands. This is done here to be able to aggregate
          # marks across phase boundaries
          case [!current_mark.nil?, unit.is_a?(Unit::Mark)]
            in [false, true]; current_mark = Unit::Marks.new(unit); next # Create new Marks object
            in [true, true]; current_mark.marks << unit; next # Add additional Mark object and skip rest
            in [true, false] # Flush Marks object
              @execute_units << Unit::Transaction.new(:COMMIT) << current_mark
              commit_after = false
              current_mark = nil
              next
            in [false, false]; # Fall-through, not a mark command
          end

          # Associated Idr node
          node = nodes[unit]

          # Insert commit node if required. A series of commit-before nodes
          # will only yield a node for the initial commit
          if node.require_commit_before?
            if !commit_before
              @execute_units << Unit::Transaction.new(:COMMIT)
              commit_before = true
            end
          else
            commit_before = false
          end

          # Insert commit node if required. A series of commit-after nodes
          # will only yield a node for the final commit. Note that this is
          # triggered by the node following the last commit-after node, that's
          # why this code is place before the node is added and not after
          if node.require_commit_after?
            commit_after = true
          elsif commit_after
            @execute_units << Unit::Transaction.new(:COMMIT)
            commit_after = false
          end

          # Handle schema nodes
          if this_schema = compiler.schemas[unit.schema]

            # Insert search path node if needed
            if node.require_search_path? && this_schema != current_schema
              @execute_units << Unit::SearchPath.new(this_schema.ident) if !this_schema.program?
              current_schema = this_schema
            end

            # Add unit
            @execute_units << unit

            # Reset search path
            current_schema = nil if node.change_search_path?

          else
            @execute_units << unit
          end
        }
      }
    end

    def collapse_mark_units
      @execute_units
    end

    def generate_final_units
      @execute_units << Unit::Transaction.new(:END)
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

#   def generate_script_units
#     units.each { |unit|
#       if unit.phase
#         attr = CATEGORIES[unit.phase]
#         self.send(attr) << unit
#       end
#     }
#   end
  end
end

