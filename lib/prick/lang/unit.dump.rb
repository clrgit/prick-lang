module Prick::Lang
  module Unit
    class Node
      def dumpunit
#       print "#{phase} "
        node.dumpunit
      end

      def dumpline = node.dump
      def dumpdep = node.dump

#     def dump = puts "#{self.classname} #{node.token&.kind || 'nil'} #{node.token&.text || 'nil'}"
      def dump = puts "#{self.classname}"

#     def dump = puts "#{node.token.kind} #{node.token.text}"
#     def dump = dumpline
#     def dump = puts "#{phase} #{node.token.kind} #{node.token.text}"
    end

    class SearchPath
      def dump = puts "#{self.classname} #{schema.ident}"
    end

    class IdrNode
      def dump = puts "#{self.classname} #{node.token&.kind || 'nil'} #{node.token&.text || 'nil'}"
    end

    class ResetSchema
    end

    class DropSchema
    end

    class SearchPath
      def dumpline = puts "set search_path to '#{node.schema.ident || "public"}'"
      def dumpdep = puts "set search_path to '#{node.schema.ident || "public"}'"
    end

    class Command
    end

    # Head/tail nodes
    class Mark
      def dump = puts "#{self.classname} #{resource}"
      def dumpunit = node.dumpline
    end

    class Meta
      def dumpunit = node.dumpline
    end

    class DetectMeta
      def dumpunit = node.dumpline
    end
  end
end


