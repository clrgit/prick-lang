
module Prick::Lang
  class Analyzer
    using String::Text
    include ErrorFunctions

    def compiler = Compiler.instance
    def idr = compiler.idr

    def initialize
    end

    def analyze
      assign_default_phases
      assign_nop_nodes
      assign_command_schema
      resolve_references
      link_block_nodes
      link_phases
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
    def assign_default_phases
      # Assign default phases and add them to the resource repository
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

    def assign_nop_nodes
      # Add a Nop node to empty blocks
      idr.nodes(Idr::Resource).each { |resource|
#       if resource.block.empty?
          resource.block << Idr::ResourceCommand.new(resource)
#       end
      }
    end

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

    def link_phases
      idr.nodes(Idr::Schema).each { |schema|
        schema.init.prev = schema.head.this # TODO: No! schema.head is special-handled
        schema.block.first.prev = schema.init.this
        schema.seed.prev = schema.block.last.this
        schema.term.prev = schema.seed.this
        schema.auth.prev = schema.term.this
      }
    end
  end
end

# schema
#   init
#     init.sql
#   self
#     self.sql
#   seed
#     seed.sql
#   term
#     term.sql
#
# schema.prev -> term
# term.prev -> seed
# seed.prev -> self
# self.prev -> init
# init.prev -> decl
# decl.prev -> nil
#
# term.sql -> seed.sql
#














