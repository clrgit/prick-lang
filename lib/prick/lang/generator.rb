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

    # A Unit::Meta object that collects all Idr::MetaCommand tables
    attr_reader :meta

    # Nodes by unit. Used to lookup the associated node without polluting Unit
    # with compiler objects
    attr_reader :nodes # {Unit => Node}

    # Units and associated node by phase in dependency order. Note that all
    # phases are present even if they have no nodes
    attr_reader :phases # {PHASE=>[Unit::Node]}

    # List of all targeted schemas
    attr_reader :target_schemas # [Schema]

    # List of seed-exlusive schemas. These schemas recieve data-only updates
    # and needs not be rebuilt
    attr_reader :seed_schemas # [Schema]

    # Generated schemas. These schemas are reset and then rebuilt by prick.
    # They do not include schemas of only seed objects
    attr_reader :build_schemas # [Schema]

    # Invalidated schemas. These schemas depends on #build_schemas but are not
    # included in the target schemas and are deleted by prick
    attr_reader :invalid_schemas # [Schema]

    # Schemas that are defined but not rebuilt and not invalid
    attr_reader :preserve_schemas # [Schema]

    # List of schemas that will be rebuilt or invalidated (ie. seed-only
    # schemas are not included). Equal to #build_schemas+#invalid_schemas
    def affected_schemas = build_schemas + invalid_schemas # [Schema]

    # Affected phases
    attr_reader :affected_phases # [Phase]

    # Nodes selected by the targets
    attr_reader :selected_nodes

    # Final set of units in execution order
    attr_reader :execute_units # [Unit]

    def dump
      puts "Generator"; indent {
        puts "Idr units: #{units.size}"
        puts "Meta"; indent {
          puts "Schemas: #{meta.schemas.join(', ')}"
          puts "Tables: #{meta.tables.map { _1.join('.') }.join(', ')}"
        }
        puts "Phases"; indent {
          puts "affected: #{affected_phases.map &:ident}"
          phases.each { |k,v|
            puts "#{k.downcase}: #{v.size}"
          }
        }
        puts "Schemas"; indent {
          puts "targets: #{target_schemas.map &:ident}"
          puts "seeds: #{seed_schemas.map &:ident}"
          puts "build: #{build_schemas.map &:ident}"
          puts "invalid: #{invalid_schemas.map &:ident}"
          puts "preserve: #{preserve_schemas.map &:ident}"
          puts "affected: #{affected_schemas.map &:ident}"
        }
        puts "Executable units: #{execute_units.size}"

#       puts "Nodes"; indent {
#         selected_nodes.each(&:dumpline)
#       }
      }
    end

    def initialize
    end

    def generate
      # Build graph
      @graph = analyzer.reachable_nodes.map { |node| [node, node.deps] }.to_h

      # Sort nodes
      tsorted_nodes = topological_sort

      # Select nodes for the current compiler mode (:build/:make)
      @selected_nodes = tsorted_nodes.select { _1.send(mode_method) }

      # Assign schemas
      if mode == :merge
        @target_schemas = @selected_nodes.map(&:schema).compact.reject(&:program?)
        @seed_schemas = []
        @build_schemas = []
        @invalid_schemas = []
        @preserve_schemas = idr.schemas
        @affected_schemas = []
        @affected_phases = [] # FIXME

        # TODO Check that all seed tables have been covered
      else
        non_seed_schemas = Set.new
        seed_schemas = Set.new
        @selected_nodes.each { |node|
          next if node.schema.nil?
          next if node.is_a? Idr::Program
          if node.seed?
            if !non_seed_schemas.include? node.schema
              seed_schemas.add node.schema
            else
              ;
            end
          elsif seed_schemas.include? node.schema
            seed_schemas.delete node.schema
            non_seed_schemas.add node.schema
          else
            non_seed_schemas.add node.schema
          end
        }

        @target_schemas = non_seed_schemas.to_a + seed_schemas.to_a
        @seed_schemas = seed_schemas.to_a
        @build_schemas = @target_schemas - @seed_schemas
        @invalid_schemas = transitive_closure(@build_schemas, &:schema_reqs) - @target_schemas
        @preserve_schemas = idr.schemas - affected_schemas
        @affected_schemas = @build_schemas + @invalid_schemas
        @affected_phases = program.phases.values.select(&mode_method)
      end

      # Build units and assign to phases. Initializes @phases, @units, and @nodes
      build_units @selected_nodes

      # Units to execute
      @execute_units = []

      # Assign initial units (creates/drops schemas) and set up transaction
      generate_initial_units

      # Join phases in execution order
      generate_script_units

      # Assign final units and commit outstanding changes
      generate_final_units
    end

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
      @meta = Unit::Meta.new build_schemas.map(&:uid) # Idr::MetaCommands-case needs this
      unit_classes = { SQL: Unit::SqlFile, PSQL: Unit::PSqlFile, FOX: Unit::FoxFile, RB: Unit::RubyFile }
      nodes.each { |node|
        unit =
            case node
              when Idr::FileCommand
                unit_classes[node.kind].new(node.path) or raise InternalError
              when Idr::SqlCommand
                Unit::Sql.new node.source
              when Idr::ExternalCommand
                Unit::Bash.new node.kind, node.source
              when Idr::CallCommand
                Unit::Call.new node.procs
              when Idr::MakeMetaCommand
                @meta # This places the meta command at the right spot. TODO: Where?
              when Idr::MetaCommand
                @meta.add_table node.schema_name, node.table_name
                next
              when Idr::MakeSeedCommand
                Unit::Seed.new seed_schemas.map(&:uid)
              when Idr::TailCommand
                Unit::Mark.new node.phase, node.schema&.ident, node.uid
              when Idr::CopyCommand
                Unit::Copy.new node.table, node.source
              when Idr::SyncCommand
                Unit::Sync.new node.table, node.key, node.id_table, node.source
              when Idr::PrepareCommand
                Unit::Prepare.new node.table, node.key, node.id_table, node.source
              when Idr::HandleCommand
                Unit::Handle.new node.table, node.source
              when Idr::ProvideCommand
                Unit::Mark.new node.phase, node.schema&.ident, node.uid
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

    #
    # G E N E R A T E   M E T H O D S
    #

    # Drop/reset schemas and delete invalid resources entries
    #
    # TODO: Check that seed is not running on existing seeded targets
    def generate_initial_units
      # Initial begin
      @execute_units << Unit::Transaction.new(:BEGIN)

      # Unmark
      @execute_units << Unit::UnMarks.new(affected_phases.map(&:ident), affected_schemas.map(&:ident))

      # Drop/reset dirty schemas
      if mode != :merge
        @execute_units.concat \
            invalid_schemas.map { |schema| Unit::Db.new(schema.ident, :DROP) } +
            build_schemas.map { |schema| Unit::Db.new(schema.ident, :RESET) }
      end
    end

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
              @execute_units << current_mark << Unit::Transaction.new(:COMMIT)
              commit_after = false
              current_mark = nil
              # fall through - current node is not a Mark
            in [false, false]
              ; "nop - not a mark command"
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

          # Add search_path if required
          if this_schema = node.schema
            # Insert search path node if needed
            if node.require_search_path? && this_schema != current_schema
              @execute_units << Unit::SearchPath.new(this_schema.ident.to_s.downcase) if !this_schema.program?
              current_schema = this_schema
            end

            # Add unit
            @execute_units << unit

            # Reset search path if node may change it
            current_schema = nil if node.change_search_path?

          else
            @execute_units << unit
          end
        }
      }

      @execute_units << current_mark << Unit::Transaction.new(:COMMIT) if current_mark
    end

    def generate_final_units
      # Remove COMMIT-END combination
      last = @execute_units.last
      @execute_units.pop if last.is_a?(Unit::Transaction) && last.command == :COMMIT

      # Add final END commit
      @execute_units << Unit::Transaction.new(:END)
    end

    #
    # G R A P H   M E T H O D S
    #

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
  end
end

