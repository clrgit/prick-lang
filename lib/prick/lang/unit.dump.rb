module Prick::Lang
  module Unit
    class Node
      def dump(*rest) = _dump(*rest)
    protected
      def _dump(*rest) = puts self.classname + (rest.empty? ? "" : " " + rest.join)
    end

    class SchemaCommand
      def dump = super "#{command.upcase} #{schema.ident}"
    end

    class SearchPath
      def dump = super schema.ident
    end

    class Command
      def dump = super "#{node.token&.kind || 'nil'} #{node.token&.text || 'nil'}"
    end

    class FileCommand
      def dump = _dump "#{node.kind} #{node.path}"
    end

    # Head/tail nodes
    class Mark
      def dump = super resource
    end
  end
end

__END__




      def dumpunit
#       print "#{phase} "
        node.dumpunit
      end

      def dumpline = node.dump
      def dumpdep = node.dump

#     def dump = puts "#{self.classname} #{node.token&.kind || 'nil'} #{node.token&.text || 'nil'}"

#     def dump = puts "#{node.token.kind} #{node.token.text}"
#     def dump = dumpline
#     def dump = puts "#{phase} #{node.token.kind} #{node.token.text}"
