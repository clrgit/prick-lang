
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

#   attr_reader :reachable_schemas

    # Analyze IDR. The link flag controls which part of the process are
    # executed, it is used to dump the Idr at different stages
    #
    #   link=true -> run link only
    #   link=false -> run assign only
    #   link=nil -> run assign+link (the default)
    #
    def analyze(link: nil)
      if link.nil? || !link # Assign
        collect_schemas
        assign_this_phase
        assign_default_phases
        add_phase_nodes
        add_detect_meta_nodes
        assign_schema
        assign_phases
        collect_meta
        resolve_references
        assign_schema_deps
      end
      if link.nil? || link # Link
        link_block_nodes
#     puts "HERE"

#     p program.deps.map(&:parent).map(&:ident)
#     p program.reqs.map(&:parent).map(&:ident)
        link_phases
#     p program.deps.map(&:parent).map(&:ident)
#     p program.reqs.map(&:parent).map(&:ident)
        link_program_phases
        mark_nodes
        select_nodes
#     p program.deps.map(&:parent).map(&:ident)
#     p program.reqs.map(&:parent).map(&:ident)
#     exit
      end
      idr
    end

    def inspect() = "<#{self.class}>"

    def dump(marks: false)
      puts "Prick Files"; indent {
        ast.nodes(Ast::SourceFile) { |file|
          dirty = is_dirty?(file.path) ? "D" : " "
          puts "#{dirty} #{file.path}"
        }
      }

      puts "Source files"; indent {
        ast.nodes(Ast::File) { |file|
          dirty = is_dirty?(file.path) ? "D" : " "
          puts "#{dirty} #{file.path}"
        }
      }

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

      puts "Schema"
    end

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

    # Add detect meta node at the end of the program term phase
    def add_detect_meta_nodes
      phase = program.phases[:TERM]
      phase.block.append Idr::CheckMetaCommand.new(phase)
    end


#     idr.nodes(Idr::Phase).select { _1.kind == :TERM }.each { |phase|
# #     idr.trees(Idr::Phase).select { _1.kind == :TERM }.each { |phase|
#       if phase.kind == :TERM && phase.parent == idr
#         phase.block.append Idr::CheckMetaCommand.new(phase)
#       end
#     }
#   end

    # Assign Node#schema. TODO Do we check for sql in main?
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

    # Assign Schema#meta_commands
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

    # Exclude nodes (schemas) from the command line
    def mark_excluded_nodes
      compiler.exclude.map { compiler.resources[_1] }.each(&:exclude!)
    end

    # Include targets
    def mark_included_nodes
      compiler.targets.map { compiler.resources[_1] }.each(&:include!)
    end

    # Mark excluded/included nodes
    def select_nodes
      # Find reachable nodes and schemas
      @reachable_nodes = program.nodes(&:included?)
#     @reachable_schemas = @reachable_nodes.map(&:schema).uniq # Expensive
    end
  end
end















