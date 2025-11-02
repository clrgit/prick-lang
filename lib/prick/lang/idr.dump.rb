
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

      def dumpdep = dumpline

      def dumpunit = puts "#{self.token&.kind || 'nil'} #{self.token&.text}"

      def dump_parts
#       indent {
#         puts "self: #{serial}"
#         puts "head: #{head.serial}"
#         puts "tail: #{tail.serial}"
#         puts "deps: #{deps.map(&:serial)}"
#       }
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
      def dumpunit
        puts "SQL"
        indent {
          puts "drop schema if exists #{schema.uid};"
          puts "create schema #{schema.uid}"
        }
      end
#     def dumpunit = puts "SQL create schema #{schema.uid}"
      def dumpline = puts "SQL create schema #{schema.uid}"
    end

    class FileCommand
      def dumpline = puts "FILE #{path}"
      def dumpunit = puts "#{token&.kind || 'nil'} #{path}"
    end

    class ExternalCommand
      def dumpunit
        command = ast.kind
        if ast.multiline?
          puts command; indent { puts source }
        else
          puts "#{command} #{source}"
        end
      end

      def dumpline = puts "#{ast.kind} #{source.sub(/\..*/m, "")}"

      def dump
        command = ast.kind.downcase
        if ast.multiline?
          puts command; indent { puts source }
        else
          puts "#{command} #{source}"
        end
      end
    end

    class CallCommand
      def dumpline = puts "call #{ident}"
    end

    class RequireCommand
      def dumpline = puts "require #{uid} -> #{node ? node.classname : node.inspect}"
      def dumpdep = puts "REQ #{uid}"
    end

    class NopCommand
      def dumpline = puts "NOP #{parent.uid || parent.class}"
    end

    class MarkCommand
      def dumpline
        if parent.is_a?(Idr::Schema)
          puts "MARK #{parent.uid || "public"}"
        else
          puts "MARK #{parent.uid || parent.class}"
        end
      end
      def dumpdep = dumpline
    end

    class ProvideCommand
      def dumpline = puts "provide #{uid}"
      def dump = dumpline
      def dumpdep = puts "PROP #{uid}"
      def dump_parts = nil # nop
    end

    class MakeCommand
      def dumpline = puts "MAKE"
    end

    # Can be a schema, phase, provide, or function
    class Resource
      def dump(ident = self.ident)
        puts ident; dump_parts
      end
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
#     PARTS = [:create, :functions, :phases, :block]
      PARTS = [:create, :functions, :phases]
      def dumpunit = puts "SCHEMA #{ident}"
    end

    class Program
#     PARTS = [:functions, :phases, :schemas, :block]
      PARTS = [:functions, :phases, :schemas]
      def dump = super "Program"
      def dumpunit = puts "PROGRAM"
    end

    class Unresolved
      def dumpline = puts "UNRESOLVED #{uid}"
    end
  end
end

