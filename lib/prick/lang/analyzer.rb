
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
    attr_reader :reachable_schemas

    def analyze
      assign_this_phase
      assign_default_phases
      add_mark_nodes
      assign_schema
      resolve_references
      link_block_nodes
      link_phases
      link_program_phases
      select_nodes
      idr
    end

    def inspect() = "<#{self.class}>"

    def dump
      puts "Nodes"; indent {
        idr.nodes.sort_by(&:serial).each { |node|
          deps = node.deps.empty? ? 'nil' : node.deps.map(&:serial).map(&:inspect).join(", ")
          printf "%3s -> %s ", node.serial, deps
          node.dumpdep
        }

#       idr.trees(Idr::Command).sort_by(&:serial).each { |node|
#         deps = node.deps.empty? ? 'nil' : node.deps.map(&:serial).map(&:inspect).join(", ")
#         printf "%3s -> %s ", node.serial, deps
#         node.dumpdep
#       }
      }

      puts "Resources"; indent {
        compiler.present.each { |uid|
          r = compiler.resources[uid]
          puts "#{uid} -> #{r.tail.serial}"
        }
      }
    end

  private

    # Assign Schema#this phases by stealing the schema's block
    def assign_this_phase
      idr.nodes(Idr::Schema).each { |schema|
        schema.this.retach(schema.block)
        schema.this.block = schema.block
        schema.block = []
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

    # Add a Mark NOP node to all blocks. This node becomes the #tail node of
    # the containing node (and the #head node too if the block is empty)
    def add_mark_nodes
      idr.nodes(Idr::Resource).each { |resource|
        resource.block << Idr::MarkCommand.new(resource)
      }
    end

    # Assign Node#schema schema
    def assign_schema
      idr.nodes(Idr::Schema).each { |schema|
        schema.nodes.each { |node| node.schema = schema }
      }
    end

    # Link up require statements with the referenced resources
    def resolve_references
      idr.nodes(Idr::RequireCommand).each { |require_|
        compiler.present?(require_.uid) or error(require_, "Can't find resource '#{require_.uid}'")
        require_.node = compiler.resources[require_.uid].tail
      }
    end

    # Link up nodes in resource blocks. The first node has no previous node
    def link_block_nodes
      idr.nodes(Idr::Resource).each { |resource|
        prev = nil
        resource.block.each { |node|
          node.depend_on prev if prev
          prev = node
        }
      }
    end

    # Link up phases internally in schemas and programs
    def link_phases
      ([program] + program.schemas).each { |schema|
#       schema.init.depend_on program.init if schema != program
        schema.this.depend_on schema.init
        schema.term.depend_on schema.this
        schema.seed.depend_on schema.term
        schema.auth.depend_on schema.seed

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
      }
    end

    # Mark excluded/included nodes
    def select_nodes
      # Exclude nodes (schemas) from the command line
      compiler.exclude.map { compiler.resources[_1] }.each(&:exclude!)

      # Include targets
      targets.each(&:include!)

      # Exclude completed_resources TODO
#     Idr.transitive_closure(completed_resources).each { |node| node.exclude = true }

      # Find reachable nodes and schemas
      @reachable_nodes = Idr.transitive_closure(targets, kind: :include)
      @reachable_schemas = @reachable_nodes.map(&:schema).uniq # Expensive
    end
  end
end

















