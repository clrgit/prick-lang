
module Prick::Lang
  class Analyzer < CompilerProcess
    using String::Text

    # Top-level program object. A more informative synonym for #idr
    def program = compiler.idr

    # Target nodes
    def targets # [Node]
      @targets ||=
        if compiler.targets.include? Compiler::DEFAULT_TARGET
          [program] #.schemas.reject(&:exclude)
        else
          compiler.targets.map { compiler.resources[_1] }
        end
    end

    attr_reader :reachable_nodes
#   attr_reader :reachable_schemas

    # Analyze IDR. The link flag controls which part of the process are
    # executed. It is used to dump the Idr at different stages
    #
    #   link=true -> run link only
    #   link=false -> run assign only
    #   link=nil -> run assign+link
    #
    def analyze(link: nil)
      if link.nil? || !link # Assign
        assign_this_phase
        assign_default_phases
        add_phase_nodes
        add_detect_meta_nodes
        assign_schema
        collect_meta
        resolve_references
      end
      if link.nil? || link # Link
        link_block_nodes
        link_phases
        link_program_phases
        mark_nodes
        select_nodes
      end
      idr
    end

    def inspect() = "<#{self.class}>"

    def dump(marks: false)
      puts "Nodes (D - dirty, B - built, I - included, X - excluded, * - rebuild)"; indent {
        idr.nodes.sort_by(&:serial).each { |node|
          deps = node.deps.empty? ? 'nil' : node.deps.map(&:serial).map(&:inspect).join(", ")
          reqs = node.reqs.empty? ? '' : node.reqs.map(&:serial).map(&:inspect).join(", ")
          if marks
            flags =
              (node.dirty? ? "D" : " ") +
              (node.built? ? "B" : " ") +
              (node.excluded? ? "X" : " ") +
              (node.included? ? "I" : " ") +
              (compiler.mode == :build && node.build? || compiler.mode == :make && node.make? ? "*" : " ") +
              " "
          else
            flags = ""
          end
          printf "#{flags}%3s -> %s [%s] ", node.serial, deps, reqs
          node.dumpdep
        }
      }

      puts "Resources"; indent {
        compiler.present.each { |uid|
          node = compiler.resources[uid]

          if marks
            flags =
              (node.dirty? ? "D" : " ") +
              (node.built? ? "B" : " ") +
              (node.excluded? ? "X" : " ") +
              (node.included? ? "I" : " ") + " "
          else
            flags = ""
          end
          printf flags
          puts "#{uid} -> #{node.tail.serial}"
        }
      }
    end

  private

    # Assign Schema#this phases by stealing the schema's block. The phase is
    # added to the resource repository
    def assign_this_phase
      idr.nodes(Idr::Schema).each { |schema|
        schema.this.retach(schema.block)
        schema.this.block = schema.block
        schema.block = []
        compiler.add(schema.this)
      }
    end

    # Assign default phases and add them to the resource repository
    def assign_default_phases
      idr.nodes(Idr::Schema).each { |schema|
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

    # Add detect meta node at the end of the program term phase
    def add_detect_meta_nodes
      idr.trees(Idr::Phase).select { _1.kind == :TERM }.each { |phase|
        if phase.kind == :TERM && phase.parent == idr
          phase.block.append Idr::DetectMetaCommand.new(phase)
        end
      }
    end

    # Assign phases
    def assign_phases
      idr.trees(Idr::Phase).each { |phase|
        phase.nodes.each { |node| node.phase = phase.kind }
      }
    end

    # Assign Node#schema schema
    def assign_schema
      idr.nodes(Idr::Schema).each { |schema|
        schema.nodes.each { |node| node.schema = schema }
      }
    end

    def collect_meta
      idr.nodes(Idr::MetaCommand).each { |meta|
        meta.schema.meta_commands << meta
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
#       schema.merge.depend_on schema.auth
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
#       program.merge.depend_on schema.merge
      }
    end

    # Helper function
    def is_dirty?(path) = File.exist?(path) && File.mtime(path) > compiler.timestamp

    # Mark dirty (changed) files. Note that absent files are not dirty because
    # they may be generated later, if not it will cause an error when executed
    def mark_dirty_nodes
      program.trees(Idr::FileCommand).each { |cmd|
        cmd.dirty! if is_dirty? cmd.path #File.exist?(cmd.path) && File.mtime(cmd.path) > compiler.timestamp
      }
    end

    # Mark nodes defined in dirty build files
    def mark_dirty_build
      # FIXME FIXME FIXME This is where the source column in the resources table is used !!!

      # Find dirty prick files
      dirty_sources = compiler.sources.select { is_dirty? _1.file.path }

      # Mark Ast nodes dirty
      dirty_sources.each { |source| source.dirty!  }

      # Mark resource Idr objects dirty if they have a dirty Ast node
      compiler.resources.values.each { |node| node.dirty! if node.ast&.dirty? }

      # Propagate dirty
#     program.nodes(Idr::Resource, Idr::ProvideCommand).each { |cmd| cmd.dirty! if cmd.ast&.dirty?  }
    end

    # Mark nodes that are already built. Note that completed_resources may be
    # nil. This happens when the compiler state file is absent
    def mark_built_nodes
      compiler.completed_resources&.each { |uid| compiler.resources[uid]&.built!  }
    end

    # Exclude nodes (schemas) from the command line
    def mark_excluded_nodes
      compiler.exclude.map { compiler.resources[_1] }.each(&:exclude!)
    end

    # Include targets
    def mark_included_nodes
      compiler.targets.map { compiler.resources[_1] }.each(&:include!)
    end

    def mark_nodes
      mark_built_nodes
      mark_dirty_build
      mark_dirty_nodes
      mark_excluded_nodes
      mark_included_nodes
    end

    # Mark excluded/included nodes
    def select_nodes
      # Find reachable nodes and schemas
      @reachable_nodes = program.nodes(&:included?)
#     @reachable_schemas = @reachable_nodes.map(&:schema).uniq # Expensive
    end
  end
end















