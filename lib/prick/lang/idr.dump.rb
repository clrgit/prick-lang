
module Prick::Lang
  using String::Text
  module Idr
    class Node
      DUMP_ORDER = [:head, :init, :term, :meta, :seed, :auth, :functions, :schemas, :block]

      def part_dump_order
        ordered_parts = DUMP_ORDER & parts.keys
        remaining_parts = parts.keys - ordered_parts
        ordered_parts + remaining_parts
      end

      def inspect = "<#{self.classname}>"

      def dump(text = nil)
        if !parts.empty?
          puts "#{text}:" if text
          indent { dump_parts }
        else
          print "#{text}: " if text
          dump_value
        end
      end

      def dump_value() = puts "ASDF"

      def dump_parts
        part_dump_order.map { |attr| [attr, parts[attr]] }.each { |ident, value|
          next if value.nil? || value.is_a?(Nodes) && value.empty?
          value.dump(ident)
        }
      end
    end

    class Nodes
      def dump(text = nil)
        if text
          puts "#{text}:"
          indent { dump_parts }
        else
          dump_parts
        end
      end

      def dump_parts = self.each(&:dump)
    end

    class Command
    end

    # Artificial node that creates a schema
    class SchemaCommand
      def dump_value = puts "sql create schema"
    end

    class FileCommand
      def dump_value = puts "file #{path}"
    end

    class ExternalCommand
      def dump_value
        command = ast.kind.downcase
        if ast.multiline?
          puts command; indent { puts source }
        else
          puts "#{command}: #{source}"
        end
      end
    end

    class CallCommand
      def dump_value = puts "call #{ident}"
    end

    # Can be a schema, phase, provide, or function
    class Resource
      def dump(text = nil)
        super(text || ident)
      end

    end

    class Phase
    end

    class Provide
      def dump = puts "provide #{uid}"
    end

    class Function
    end

    class Schema
    end

    class Program
      def dump = super("Program")
    end

    class Require
      def dump = puts "require #{uid} -> #{node.classname}"
    end

    class Unresolved
      def dump() = super "UNRESOLVED #{uid}"
    end
  end
end


