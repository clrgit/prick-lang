
module Prick::Lang
  module Unit
    class Node
      include ClassFunctions

      # Connection object. Initialized by the executer
      @@CONN = nil
      def self.conn=(conn) @@CONN = conn end
      def conn() @@CONN end

      # Bash object. Initialized by the executer
      @@BASH = nil
      def self.bash=(bash) @@BASH = bash end
      def bash() @@BASH

      def execute() = raise
    end

    class Db < Node
      COMMANDS = [:ensure, :drop]

      attr_reader :schema # String
      attr_reader :command # :ensure, :drop

      def initialize(schema, command)
        @schema, @command = schema, command
      end

      def execute
        case command
          when :ensure
            conn.schema.drop schema, cascade: true
            conn.schema.create schema
          when :drop
            conn.schema.drop schema, cascade: true
        else
          raise InternalError
        end
      end
    end

    class Mark < Node
      attr_reader :uid
      def initialize(uid) @uid = uid end
      def execute = conn.insert "prick.resources", uid: uid
    end

    class Meta < Node
      attr_reader :table # qualified table name
      def initialize(table) @table = table end
      def execute = conn.proc :"prick.register_meta_table", table
    end

    class Sql < Node
      attr_reader :sql
      def initialize(sql) @sql = sql end
      def execute = conn.exec sql
    end

    class Call < Sql
      attr_reader :proc
      def initialize(proc) @proc = proc end
      def execute = conn.proc @proc
    end

    class DetectMeta < Call
      def initialize() = super :"prick.register_meta_tables"
    end

    class File < Node
      attr_reader :file
      def intialize(file) @file = file end
      def read() IO.read(file) end # TODO Error handling
    end

    class SqlFile < File
      def execute = conn.exec read
    end

    class PSqlFile < File
      def execute = bash.command "psql -U #{settings.username} -d #{settings.database} <#{file}"
    end

    class FoxFile < File
#     def execute = bash.command "fox -U #{settings.username} -d #{settings.database} \#{files}" # FIXME files
      def execute = bash.command "echo TODO FOX"
    end

    class RubyFile < File
      def execute = bash.command "echo TODO RUBY"
    end

    class Bash < Node
      attr_reader :kind # :EXEC or :EVAL
      attr_reader :command
      def initialize(kind, command) @kind, @command = kind, command end
      def execute
        sql = bash.command command
        conn.exec sql if kind == :EVAL
      end
    end

    class Copy < Node
      attr_reader :tables
      def initialize(tables) @tables = tables end
      def execute = bash.command "echo TODO COPY"
    end

    class AbstractPrepareSync < Node
      attr_reader :table
      attr_reader :key
      attr_reader :id_table
      attr_reader :sql

      def initialize(table, key, id_table = nil, sql = nil)
        @table, @key, @id_table, @sql = table, key, id_table, sql
      end
    end

    class Sync < AbstractPrepareSync
      def execute = bash.command "echo TODO SYNC"
    end

    class Prepare < AbstractPrepareSync
      def execute = bash.command "echo TODO PREPARE"
    end

    class Handle < Node
      attr_reader :tables
      def initialize(tables) @tables = tables end
      def execute = bash.command "echo TODO HANDLE"
    end
  end
end

__END__




    class ClearSchemaSeed < Node
    end

    class DetectMeta < Node
    end

    class SearchPath < Node
      attr_reader :schema # Idr::Schema
      def schema_name = schema.ident
      def initialize(schema) @schema = schema end

      def execute
        conn.search_path = schema_name
      end
    end

    class IdrNode < Node
      attr_reader :node # Idr::Node
      forward_to :node, :schema, :require_search_path?, :change_search_path?

      def schema_name = schema.ident

      def initialize(node)
        constrain node, Idr::Node
        @node = node
      end
    end

    class  < IdrNode
    end

    # Mark a resource as built by inserting a record in prick.resources. It is
    # generated from tail nodes
    class Mark < IdrNode
      def resource = node.uid
    end

    class Meta < IdrNode
    end
  end
end


