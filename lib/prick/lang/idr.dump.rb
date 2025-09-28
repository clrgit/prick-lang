
module Prick::Lang
  module Idr
    class Node
      def inspect = "<#{self.classname}>"

      def dump(*text) = dump_impl(*text)
      def dumps(*text, nodes) dump_impl(*text); indent { nodes.each &:dump } end

    private
      # To avoid endless recursion when #dump is redefined
      def dump_impl(*text) = puts ([self.classname] + text).compact.join(" ")
    end

    class Nodes
    end

    class Command
    end

    # Artificial node that creates a schema
    class SchemaCommand
      def dump = puts "sql create schema"
    end

    class FileCommand
      def dump = puts "file #{path}"
    end

    class ExternalCommand
      def dump
        command = ast.kind.downcase
        puts "#{command} #{ast.multiline? ? "..." : source}"
      end
    end

    class CallCommand
    end

    # Can be a schema, phase, provide, or function
    class Resource
    end

    class Phase
      def dump = dumps uid, @block
    end

    class Provide
      def dump = super uid
    end

    class Function
    end

    class Schema
      def dump()
        puts "Schema #{ident}"
        indent {
          dump_head
          dump_phases
          dump_functions
          dump_block
        }
      end

      def dump_head
        if head
          puts "head"; indent {
            head.dump
          }
        else
          puts "head: nil"
        end
      end

      def dump_functions
        puts "functions"; indent {
          functions.each(&:dump)
        }
      end

      def dump_phases
        puts "phases"; indent {
          Token::PHASES.each { |phase|
            ident = phase.downcase.to_sym
            if !parts[ident].nil?
              parts[ident].dump
            end
          }
        }
      end

      def dump_block
        puts "block"; indent {
          block.each(&:dump)
        }
      end
    end

    class Program
      def dump_schemas
        schemas.each { |schema| schema.dump }
      end
    end

    class Require
      def dump
        txt = uid
        txt += " -> #{node.class}" if node
        super txt
      end
    end

    class Unresolved
      def dump() = super(uid)
    end
  end
end


