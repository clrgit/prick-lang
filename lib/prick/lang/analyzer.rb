
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
      resolve_references
      link_block_nodes
      link_phases
      idr
    end

    def inspect() = "<#{self.class}>"

  private
    def assign_default_phases
      # Assign default phases
      idr.nodes(Idr::Schema).each { |schema|
        Token::PHASES.each { |kind|
          ident = kind.downcase
          if schema.get_phase(ident).nil?
            phase = Idr::DefaultPhase.new(schema, kind)
            schema.set_phase(ident, phase)
          end
        }
      }
    end

    def assign_nop_nodes
      # Add a Nop node to empty blocks
      idr.nodes(Idr::Resource).each { |resource|
        if resource.block.empty?
          resource.block << Idr::NopCommand.new(resource)
        end
      }
    end

    def resolve_references
      # Link up requirements
      compiler.requires.each { |require_|
        compiler.present?(require_.uid) or error require_, "Can't find resource '#{require_.uid}'"
        require_.node = compiler.resource(require_.uid)
      }
    end

    # Link up nodes in resource blocks. The first node has the resource itself
    # as the previous node
    def link_block_nodes
      idr.nodes(Idr::Resource).each { |resource|
        next if resource.is_a?(Idr::Provide)
        prev = nil
        resource.block.each { |node|
          node.prev = prev&.dep
          prev = node
        }
      }
    end

    def link_phases
      idr.nodes(Idr::Schema).each { |schema|
        schema.init.prev = schema.head.dep
        schema.block.first.prev = schema.init.dep
        schema.seed.prev = schema.block.last.dep
        schema.term.prev = schema.seed.dep
        schema.auth.prev = schema.term.dep
        schema.prev = schema.term.dep
      }
    end
  end
end



















