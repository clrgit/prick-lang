
module Prick::Lang
  using String::Text
  module Idr
    #
    # Dumping references
    #
    class Node
      def strrefname = self.classname

      def dumprefnode
        deps_str = deps.empty? ? 'nil' : deps.map(&:serial).join(', ')
        reqs_str = "[#{reqs.map(&:serial).join(', ')}]"
        puts "#{strrefname} #{serial} -> #{deps_str} #{reqs_str}"
      end

      def dumpref
        dumprefnode
        indent { children.each(&:dumpref) }
      end
    end

    class MarkCommand; def strrefname = "#{kind} #{uid}" end
    class Resource; def strrefname = ident end
    class Program; def strrefname = "<main>" end

    #
    # Dumping mess
    #

    class Node
      PARTS = []

      def strname = self.class.to_s.sub(/^.*::/, "").sub(/Command.*/, "").gsub(/(?<!^)([A-Z])/, ' \1')
      def strtext = self.token&.text
      def strline(*args) = [strname, strtext, *args].compact.join(' ')

      def dumpline(*args) = puts strline(*args)

      def dump(text = nil)
        puts text if text
        dump_parts
      end

      def dumpdep = dumpline

      def dumpunit = puts "#{self.token&.kind || 'nil'} #{self.token&.text}"

      def dump_parts
        for part in self.class::PARTS
          value = self.send(part)
          indent {
            case value
              when Ast::Source
                puts part
                indent { puts value.value }
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
#   class SchemaCommand
#     def dumpunit
#       puts "SQL"
#       indent {
#         puts "drop schema if exists #{schema.uid};"
#         puts "create schema #{schema.uid}"
#       }
#     end
#     def dumpline = puts "SQL create schema #{schema.uid}"
#   end

    class FileCommand
      def strname = kind
      def strtext = path
      def dumpunit = puts "#{token&.kind || 'nil'} #{path}"

#     def dumpline = puts "FILE #{path} #{self.classname}"
#     def dumpunit = puts "#{token&.kind || 'nil'} #{path}"
    end

#   class FoxCommand
#     def dumpline = puts "FOX #{path} #{self.classname}"
#     def dumpunit = puts "#{token&.kind || 'nil'} #{path}"
#   end

    class FoxFileCommand
      def strname = "FOX"
      def strtext = path
      def dumpunit = dumpline
    end

    module MultilineCommand
      def lead = ast.kind.to_s

      def dumpunit
        command = ast.kind.downcase
        if ast.source&.multiline?
          puts "#{lead}"; indent { puts source }
        else
          puts "#{lead} #{source}"
        end
      end

#     def strline = "#{ast.kind} #{source.value.sub(/\..*/m, "")}"
      def strname = ast.kind.upcase
      def strtext = source.value.sub(/\..*/m, "")

      def dump
        command = ast.kind.downcase
        if ast.source&.multiline?
          puts command; indent { puts source }
        else
          puts "#{command} #{source}"
        end
      end
    end

    class SqlCommand
      include MultilineCommand
    end

    class ExternalCommand
      include MultilineCommand
      def lead = super + (path == "." ? " ./" : " #{path}/")
    end

    class CopyCommand
      def strtext = tables.map(&:value).join(", ")
    end

    class SyncCommand
      def strtext = [table, key, id_table].compact.join(' ')

      def dumpline
        super
        indent { puts source.value } if source # FIXME
      end
    end

#       puts ["prepare #{table} #{key}", id_table].compact.join(' ')
    class PrepareCommand
      def strtext = [table, key, id_table].compact.join(' ')
      def dumpline
        super
        indent { puts source.value } if source
      end
#     def dumpline
#       indent(bol: false) {
#         print ["prepare #{table} #{key}", id_table].compact.join(' ')
#         if source
#           indent { puts source.value }
#         else
#           puts
#         end
#       }
#     end
    end

    class HandleCommand
      def strtext = tables.map(&:value).join(", ")
    end

    class CallCommand
      def strtext = ident
    end

    class RequireCommand
      def strtext = "#{uid} -> #{node ? node.classname : node.inspect}"
      def dumpdep = puts "REQ #{uid}"
    end

    class CheckMetaCommand
      def strtext = nil
    end

    class NopCommand
      def strtext = nil
#     def strline = "NOP #{parent.uid || parent.class}"
    end

    class MarkCommand
      def strtext
        parent.uid || (parent.is_a?(Idr::Schema) ? "public" : parent.classname)
      end

#     def dumpline
#       if parent.is_a?(Idr::Schema)
#         puts "#{kind} #{parent.uid || "public"}"
#       else
#         puts "#{kind} #{parent.uid || parent.class}"
#       end
#     end
      def dumpdep = dumpline
    end

    class MetaCommand
      def strtext = table
      def dumpdep = dumpline
    end

    class CheckMetaCommand
      def strname = "Detect"
      def strtext = "meta"
    end

    class ProvideCommand
      def strtext = uid
      def dump = dumpline
      def dumpdep = puts "PROP #{uid}"
      def dump_parts = nil # nop
    end

    # Can be a schema, phase, provide, or function
    class Resource
      def dump(ident = self.ident)
        puts ident; dump_parts
      end
    end

    class Procedure
      PARTS = [:block]
    end

    class Phase
      PARTS = [:block]
      def strname = "Phase" # Subclasses have strange names
      def strtext = uid
    end

    class Schema
#     PARTS = [:create, :functions, :phases, :block]
      PARTS = [:procedures, :meta_tables, :phases]
      def strtext = ident
      def meta_tables = meta_commands.map(&:table) # [String] Only used in dump
      def dumpunit = puts "SCHEMA #{ident}"
    end

    class Program
#     PARTS = [:functions, :phases, :schemas, :block]
      PARTS = [:procedures, :phases, :schemas]
      def dump = super "Program"
      def dumpunit = puts "PROGRAM"
    end

    class Unresolved
      def strline = uid
    end
  end
end








