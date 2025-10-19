
module Prick::Lang
  using String::Text
  module Idr
    class Node
      PARTS = []

      def dumpline = puts "#{self.classname} #{self.token&.text}"

      def dump(text = nil)
        puts text if text
        dump_parts
      end

      def dump_parts
        for part in self.class::PARTS
          value = self.send(part)
          indent {
            case value
              when Node
                puts part
                indent { value.dump }
              when Hash
                value.each { |part, value|
                  next if value.nil?
                  value.dump
                }
              when Array
                if value.empty?
                  puts "#{part}: []"
                else
                  puts part
                  indent {
                    value.each { |val|
                      case val
                        when Node; val.dump
                        else puts val.inspect
                      end
                    }
                  }
                end
              else
                puts "#{part}: #{value}"
            end
          }
        end
      end

      def dump_deps
#       self.nodes(Idr::Command, Idr::Provide).each { |node|
        self.nodes.each { |node|
          printf "%3s %3s ", node.serial, node.prev&.serial || 'nil'
          node.dump
        }
      end
    end

    class Command
      def dump = dumpline
    end

    # Artificial node that creates a schema
    class SchemaCommand
      def dumpline = puts "sql create schema"
    end

    class FileCommand
      def dumpline = puts "file #{path}"
    end

    class ExternalCommand
      def dumpline = puts "#{ast.kind.downcase} #{source.sub(/\..*/m, "")}"
      def dump
        command = ast.kind.downcase
        if ast.multiline?
          puts command; indent { puts source }
        else
          puts "#{command}: #{source}"
        end
      end
    end

    class CallCommand
      def dumpline = puts "call #{ident}"
    end

    class RequireCommand
      def dumpline = puts "require #{uid} -> #{node ? node.classname : node.inspect}"
    end

    class NopCommand
      def dumpline = puts "NOP #{parent.uid || parent.class}"
    end

    # Can be a schema, phase, provide, or function
    class Resource
      def dump(ident = self.ident) puts ident; dump_parts end
    end

    class Provide
      def dumpline = puts "provide #{uid}"
      def dump = dumpline
      def dump_parts = nil # nop
    end

    class Function
      PARTS = [:block]
    end

    class Phase
      PARTS = [:block]
    end

    class DefaultPhase
      def dumpline = puts "Phase #{uid}"
    end

    class Schema
      PARTS = [:head, :functions, :phases, :block]
    end

    class Program
      PARTS = [:functions, :phases, :schemas, :block]
      def dump = super "Program"
    end

    class Unresolved
      def dumpline = puts "UNRESOLVED #{uid}"
    end
  end
end

