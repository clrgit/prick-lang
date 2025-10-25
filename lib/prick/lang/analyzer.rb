
module Prick::Lang
  class Analyzer
    using String::Text
    include ErrorFunctions

    def compiler = Compiler.instance
    def idr = compiler.idr
    def program = compiler.idr
    def targets
      @targets ||=
        if compiler.targets.include? Compiler::DEFAULT_TARGET
          program.schemas.reject(&:exclude)
        else
          compiler.targets.map { compiler.resources[_1] }
        end
    end

    attr_reader :reachable_nodes
    attr_reader :reachable_schemas

    def initialize
    end

    def analyze
      assign_default_phases
      assign_nop_nodes
      assign_command_schema
      resolve_references
      link_block_nodes
      link_phases
      select_nodes
      link_program
      idr
    end

    def inspect() = "<#{self.class}>"

    def dump
      puts "Nodes"; indent {
        idr.trees(Idr::Command).sort_by(&:serial).each { |node|
          if node.is_a? Idr::RequireCommand
            printf "%3s -> %s ", node.serial, node.deps.map(&:serial).join(", ")
          else
            printf "%3s -> %3s ", node.serial, node.dep&.serial.inspect
          end
          node.dumpdep
        }
      }

      puts "Resources"; indent {
        compiler.present.each { |uid|
          r = compiler.resources[uid]
          puts "#{uid} -> #{r.this.serial}"
        }
      }
    end

  private
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

    # Add a Nop node to empty blocks #. Schemas gets a SchemaEnd nop
    def assign_nop_nodes
      idr.nodes(Idr::Resource).each { |resource|
        resource.block << Idr::MarkCommand.new(resource)
      }
    end

    # Add schema to all commands. This is used to control the postgres
    # search_path when executing the script
    def assign_command_schema
      idr.nodes(Idr::Schema).each { |schema|
        schema.trees(Idr::Command) { |command| command.schema = schema }
      }
    end

    # Link up require statements with the referenced resources
    def resolve_references
      idr.nodes(Idr::RequireCommand).each { |require_|
        compiler.present?(require_.uid) or error require_, "Can't find resource '#{require_.uid}'"
        require_.node = compiler.resources[require_.uid]
      }
    end

    # Link up nodes in resource blocks. The first node has no previous node
    def link_block_nodes
      idr.nodes(Idr::Resource).each { |resource|
        prev = nil
        resource.block.each { |node|
          node.prev = prev
          prev = node
        }
      }
    end

    # Link up schemas (and program) internally
    def link_phases
      ([program] + program.schemas).each { |schema|
        schema.head.prev = idr.init.this if schema != program
        schema.init.prev = schema.head.this
        schema.block.first.prev = schema.init.this
        schema.seed.prev = schema.block.last.this
        schema.term.prev = schema.seed.this
        schema.auth.prev = schema.term.this
      }
    end

    # Mark excluded/included nodes
    def select_nodes
      # Exclude nodes (schemas) from the command line
      Idr.exclude! compiler.exclude.map { compiler.resources[_1] }

      # Exclude completed_resources
#     Idr.transitive_closure(completed_resources).each { |node| node.exclude = true }

      # Find reachable nodes and schemas
      @reachable_nodes = Idr.include! targets
      @reachable_schemas = @reachable_nodes.select { _1.is_a?(Idr::Schema) && !_1.is_a?(Idr::Program) }
    end

    # Link included schemas with program
    def link_program
      @reachable_schemas.each { |schema|
        next if schema == program
        program.block.first.deps << schema.block.last.this
        program.seed.deps << schema.seed.this
        program.term.deps << schema.term.this
        program.auth.deps << schema.auth.this
      }
    end
  end
end

