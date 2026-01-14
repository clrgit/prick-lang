
module Prick::Lang
  class Analyzer < CompilerProcess
    using String::Text

    # List of schemas
    def schemas = program.schemas # [Idr::Schema]

    # List of program and schemas. Assigned by #collect_schemas
    attr_reader :schema_objects # [Idr::Schema]

    # Nodes included by the compiler while taking explicitly included/excluded
    # nodes into account
    attr_reader :reachable_nodes

    def analyze
      # Assign
      collect_schemas
      collect_merge_tables
      assign_this_phase
      assign_default_phases
      add_phase_nodes
      add_make_meta_node
      add_make_seed_node
      assign_schema
      assign_phases
      resolve_references
      assign_schema_deps

      # Check
      check_targets
      # check_merge_blocks TODO: Check that merge blocks have no requirements

      # Link
      link_block_nodes
      link_phases
      link_program_phases
      mark_nodes
      select_nodes

      # Augmented idr
      idr
    end

    def inspect() = "<#{self.class}>"

  private
    # Helper function. Return true if path exists and is modified after last
    # build. We assume that PRICK.RESOURCES maintains the state of built
    # resources so we only have to concern ourselves with objects that have
    # been modified after the last build (successful or not)
    def is_dirty?(path)
      File.exist?(path) && File.mtime(path) > compiler.timestamp
    end

    # Assign Program#schemas and Compiler#schemas
    def collect_schemas
      compiler.program.trees(Idr::Schema).each { |schema|
        compiler.program.schemas << schema
        compiler.schemas[schema.ident] = schema
      }
      @schema_objects = [program] + program.schemas
    end

    def collect_merge_tables
      compiler.program.trees(Idr::MergeCommand).each { |command|
        compiler.merge_commands[command.kind] << command
      }
    end

    # Assign Schema#this phases by stealing the schema's block. The phase is
    # added to the resource repository
    def assign_this_phase
#     ([program] + schemas).each { |schema|
      schemas.each { |schema|
        schema.this.retach(schema.block)
        schema.this.block = schema.block
        schema.block = []
        compiler.add(schema.this)
      }
    end

    # Assign default phases and add them to the resource repository
    def assign_default_phases
      schema_objects.each { |schema|
        Idr::Phase::PHASES.each { |kind, (attr, _)|
          if schema.get_phase(attr).nil?
            phase = Idr::DefaultPhase.new(schema, kind)
            schema.set_phase(attr, phase)
            compiler.add(phase)
          end
        }
      }
    end

    # Add head/tail nodes to phases
    def add_phase_nodes
      idr.nodes(Idr::Phase).each { |phase|
        phase.block.unshift Idr::HeadCommand.new(phase)
        phase.block.push Idr::TailCommand.new(phase)
      }
    end

    # Add a make-meta node at the end of the program term phase
    def add_make_meta_node
      phase = program.phases[:TERM]
      phase.append Idr::MakeMetaCommand.new(phase)
    end

    # Add a make-seed node at the end of the seed phase
    def add_make_seed_node
      phase = program.phases[:SEED]
      phase.append Idr::MakeSeedCommand.new(phase)
    end

    # Assign Node#schema. TODO will fail on sql in main - do we check for that?
    def assign_schema
      schemas.each { |schema|
        schema.nodes.each { |node| node.schema = schema }
      }
    end

    # Assign Command#phase. TODO: inline in #assign_schema
    def assign_phases
      schema_objects.each { |schema|
        schema.phases.each { |kind, phase|
          phase.block.each { |command| command.phase = kind }
        }
      }
    end

    # Link up require statements with the referenced resources
    def resolve_references
      idr.nodes(Idr::RequireCommand).each { |require_|
        compiler.present?(require_.uid) or error(require_, "Can't find resource '#{require_.uid}'")
        require_.node = compiler.resources[require_.uid]
        require_.depend_on require_.node
      }
    end

    # Link up nodes in phase and procedure blocks
    def link_block_nodes
      idr.nodes(Idr::Phase, Idr::Procedure).each { |resource|
        prev = resource.block.first
        resource.block.rest.each { |node|
          node.depend_on prev.tail
          prev = node.tail
        }
      }
    end

    # Link phases internally in schemas and programs
    def link_phases
      ([program] + program.schemas).each { |schema|
        schema.this.depend_on schema.init
        schema.term.depend_on schema.this
        schema.seed.depend_on schema.term
        schema.auth.depend_on schema.seed
        schema.merge.depend_on schema.seed
      }
    end

    # Link program and schema phases
    def link_program_phases
      program.schemas.each { |schema|
        schema.init.depend_on program.init if schema != program
        program.this.depend_on schema.this
        program.term.depend_on schema.term
        program.seed.depend_on schema.seed
        program.auth.depend_on schema.auth
        program.merge.depend_on schema.merge
      }
    end

    # Compute schema-schema dependencies. Note that this may form a cyclic
    # graph
    def assign_schema_deps
      schemas.each { |schema|
        schemas = Set.new
        schema.nodes.each { |node|
          node.deps.each { |dep|
            schemas.add(dep.schema)
          }
        }
        schema.schema_deps += schemas.to_a - [schema]
        schemas.each { |s| s.schema_reqs << schema }
      }
    end

    def mark_nodes
      # if build; mark_everything_dirty
      mark_clean_nodes
      mark_dirty_source_files
      mark_dirty_files
      mark_seed_nodes
      mark_merge_nodes
      check_merge_nodes
      mark_excluded_nodes
      mark_included_nodes
    end

    # Mark nodes that are already built
    def mark_clean_nodes
      compiler.completed_resources.each { |uid| compiler.resources[uid]&.built!  }
    end

    # Mark nodes defined in dirty source (*.prick) files
    def mark_dirty_source_files
      # Set of dirty source files
      dirty_sources = compiler.sources.values.select { is_dirty? _1.path }.map(&:path).to_set

      # Mark resources from dirty source files
      compiler.resources.values.each { |resource|
        resource.dirty! if dirty_sources.include?(resource.source_file)
      }
    end

    # Mark dirty (changed) files. Note that absent files are not dirty because
    # they may be generated later, if not it will cause an error when executed
    def mark_dirty_files
      program.trees(Idr::FileCommand).each { |cmd|
        cmd.dirty! if is_dirty? cmd.path
      }
    end

    # Mark nodes in seed phases. Seed nodes are only run if the SEED is being
    # built
    def mark_seed_nodes
      program.trees(Idr::Phase) { _1.kind == :SEED }.each { |phase|
        phase.seed!
      }
    end

    # Mark nodes in merge phases. Merge nodes are only executed when running
    # 'prick merge'
    def mark_merge_nodes
#     program.trees(Idr::Phase, kind: :MERGE) # IDEA
      program.trees(Idr::Phase) { _1.kind == :MERGE }.each { |phase|
        phase.merge!
      }
    end

    # Check that only merge nodes are dirty when merging
    def check_merge_nodes
      return if mode != :merge
      program.nodes(&:dirty?).each {
        _1.merge? or error "Target is dirty - please rebuild and restore"
      }
    end

    # Check that all seed tables have been covered
    #
    # TODO TODO TODO
    #
    # Can't do here. Must be done runtime
    def check_merge_coverage
#     program.
    end

    # Exclude nodes (schemas) from the command line
    def mark_excluded_nodes
      compiler.exclude.map { compiler.resources[_1] }.each(&:exclude!)
    end

    # Include targets
    def mark_included_nodes
      compiler.targets.each { |target|
        resource = compiler.resources[target] or error "No such target '#{target}'"
        resource.include!
      }
    end

    # Check that targets exist
    def check_targets
      compiler.targets.each { |target|
        compiler.resources[target] or error "No such target '#{target}'"
      }
    end

    # Mark excluded/included nodes
    def select_nodes
      # Find reachable nodes and schemas
      @reachable_nodes = program.nodes(&:included?)
#     @reachable_schemas = @reachable_nodes.map(&:schema).uniq # Expensive
    end
  end
end

