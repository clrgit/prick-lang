
module Prick::Lang
  # Aka. "Instruction unit"
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
      def bash() @@BASH end

      # The schema name of this this node (if any). Used to control the search path
      def schema = nil # String

      # Values are auto-converted to strings if not a Symbol
      def initialize(**attrs) # attrs: {Symbol => Object w/#to_s}
        attrs.each { |var, val|
          self.instance_variable_set(:"@#{var}", norm(val))
        }
      end

      # Execute the node
      def execute() = raise

      # String representation
      def to_s = raise

    private
      # Normalize value to be either a String, Symbol, an array of those, or
      # any object that responds to #to_s
      def norm(v)
        case v
          when Symbol, String; v
          when Array; v.map { norm(_1) }
          else v.to_s
        end
      end
    end

    class Db < Node
      attr_reader :schema
      attr_reader :command # Symbol - :RESET, :DROP

      def initialize(schema, command) = super schema: schema, command: command

      def execute
        case command
          when :RESET
            conn.schema.drop schema, cascade: true
            conn.schema.create schema
          when :DROP
            conn.schema.drop schema, cascade: true
        else
          raise ArgumentError, "Illegal command: #{command.inspect}"
        end
      end

      def to_s = "#{command} #{schema}"
    end

    class Transaction < Node
      attr_reader :command # Symbol - :BEGIN, :END, :COMMIT
      def initialize(command = :commit) = super command: command
      def execute()
        conn.commit if command != :BEGIN
        conn.transaction if command != :END
      end
      def to_s = command.to_s
    end

    class SearchPath < Node
      attr_reader :search_path
      def initialize(search_path) = super search_path: search_path
      def execute() conn.search_path = search_path end
      def to_s = "PATH #{search_path}" # TODO Move to unit.emit.rb
    end

    class Mark < Node
      attr_reader :uids
      def initialize(uids) = super uids: uids
      def execute = conn.insert "prick.resources", [:uid], uids
      def to_s = "MARK #{uids.join(', ')}"
    end

    class Meta < Node
      attr_reader :table # qualified table name
      def initialize(table) = super table: table
      def execute = conn.proc :"prick.register_meta_table", table
      def to_s = "META #{table}"
    end

    class Sql < Node
      attr_reader :sql
      def initialize(sql) = super sql: sql
      def execute = conn.execute sql
      def to_s = "SQL #{sql.inspect}"
    end

    class Call < Sql
      attr_reader :proc
      def initialize(proc) = super proc: proc
      def execute = conn.proc proc
      def to_s = out.puts "CALL #{proc}"
    end

    class DetectMeta < Call
      def initialize() = super :"prick.register_meta_tables"
    end

    class File < Node
      def kind = classname.upcase
      attr_reader :file
      def initialize(file) = super file: file
      def read = IO.read(file) # TODO Error handling
      def to_s = "#{kind} #{file}"
    end

    class SqlFile < File
      def execute = conn.execute read
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
      attr_reader :kind # "EXEC" or "EVAL"
      attr_reader :command
      def initialize(kind, command) = super kind: kind, command: command
      def execute
        sql = bash.command command
        conn.execute sql if kind == :EVAL
      end
      def to_s = "#{kind} #{bash.command}"
    end

    class Copy < Node
      attr_reader :tables
      def initialize(tables) = super tables: tables
      def execute = bash.command "echo TODO COPY"
      def to_s = "COPY #{tables.join(', ')}"
    end

    class AbstractPrepareSync < Node
      def kind = self.classname # "Sync" or "Prepare"
      attr_reader :table
      attr_reader :key
      attr_reader :id_table
      attr_reader :sql

      def initialize(table, key, id_table = nil, sql = nil)
        super table: table, key: key, id_table: id_table, sql: sql
      end
      def to_s = "#{kind} #{table} #{key} #{id_table || 'nil'} #{sql.inspect}"
    end

    class Sync < AbstractPrepareSync
      def execute = bash.command "echo TODO SYNC"
    end

    class Prepare < AbstractPrepareSync
      def execute = bash.command "echo TODO PREPARE"
    end

    class Handle < Node
      attr_reader :tables
      def initialize(tables) = super tables: tables
      def execute = bash.command "echo TODO HANDLE"
      def to_s = "HANDLE #{tables.join(', ')}"
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


