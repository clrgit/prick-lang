
module Prick::Lang
  # Aka. "Instruction unit"
  module Unit
    class Node
      include ClassFunctions
      include ErrorFunctions

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

      # Initialize a Unit using a hash from member name to value.
      #
      # Values are converted to strings if not a Symbol or nil. This is done so
      # the compiler object to string conversion only have to be done here. Eg.
      # a Unit can be fed a Ast::Ident object without the need to first convert
      # it to a string. Symbols are not converted to keep symbols in Unit as
      # symbols
      def initialize(**attrs) # attrs: {Symbol => Object w/#to_s}
        attrs.each { |var, val|
          self.instance_variable_set(:"@#{var}", norm(val))
        }
      end

      # Execute the node
      def execute() = raise "Abstract method #{self.class}#execute"

      # String representation
      def to_s = raise

    private
      # Normalize value to be either a String, Symbol, an array of those, or
      # any object that responds to #to_s
      def norm(v)
        case v
          when nil; v
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
      attr_reader :phase_name
      attr_reader :schema_name
      attr_reader :uid
      def initialize(phase_name, schema_name, uid)
        super phase_name: phase_name, schema_name: schema_name, uid: uid
      end
#     def execute = conn.insert "prick.resources", [:phase_name, :schema_name, :uid], marks
      def to_a = [phase_name, schema_name, uid] # For Marks#execute
      def to_s = "MARK #{uid}"
    end

    # Collapsed mark nodes
    class Marks < Node
      attr_reader :marks # [Mark], not converted to string
      def initialize(mark)
        super()
        @marks = [mark]
      end
      def execute = conn.insert "prick.resources", [:phase_name, :schema_name, :uid], marks.map(&:to_a)
      def to_s = "MARK #{marks.map(&:uid).join(', ')}"
    end

    # Clears all resources in the given phases and schemas
    # TODO Rename to 'clear' or 'setup' or similar
    class UnMarks < Node
      attr_reader :phases
      attr_reader :schemas
      def initialize(phases, schemas) = super phases: phases, schemas: schemas
      def execute
        sql_phases = conn.quote_list phases
        sql_schemas = conn.quote_list schemas
        phase_expr = "phase_name in #{sql_phases} and schema_name is null" if !phases.empty?
        schema_expr = "schema_name in #{sql_schemas}" if !schemas.empty?
        expr = [phase_expr, schema_expr].compact.join(" or ")
        conn.exec %(
          delete from prick.resources
          where #{expr}
        )
        conn.exec %(
          delete from prick.meta_tables
          where #{schema_expr || 'true'}
        )
        conn.exec %(
          delete from prick.seed_tables
          where #{schema_expr || 'true'}
        )
      end
      def to_s = "UNMARK #{(phases + schemas).map { _1 || 'nil' }.join(', ')}"
    end

    class Meta < Node
      # Affected schemas from Idr::MakeMetaCommand
      attr_reader :schemas # [String]

      # Array of [schema_name, table_name] tuples from Idr::MetaCommand
      attr_reader :tables

      def initialize(schemas) = super schemas: schemas, tables: []
      def add_table(schema_name, table_name) = @tables << [schema_name, table_name]
      def uids = tables.map { _1.join('.') } # Table uids

      def execute
        uid_list = conn.quote_list(uids)

        # Check for undeclared meta table
        absent_tables = conn.values %(
            select schema_name || '.' || table_name
            from prick.current_serials
            where schema_name in #{conn.quote_list(schemas)}
            and (schema_name || '.' || table_name) not in #{uid_list}
            and value > 1
        )

        if !absent_tables.empty?
          error "Found undeclared meta table(s): #{absent_tables.join(', ')}"
        end

        # Create meta tables
        conn.exec %(
          insert into prick.meta_tables (schema_name, table_name, value)
            select schema_name, table_name, value
            from prick.current_serials
            where schema_name || '.' || table_name in #{uid_list}
        )
      end

      def to_s = "META #{(schemas+uids).join(', ')}"
    end

    # Should check that meta tables are untouched
    class Seed < Node
      # Affected schemas
      attr_reader :schemas # [String]

      def initialize(schemas) = super schemas: schemas

      def execute
        # Check for altered meta tables
        meta_tables = conn.structs %(
            select
              m.schema_name || '.' || m.table_name as "uid",
              c.value <> m.value as "altered"
            from prick.meta_tables m
            join prick.current_serials c
              on c.schema_name = m.schema_name
              and c.table_name = m.table_name
        )

        altered_tables = meta_tables.select(&:altered).map(&:uid)
        if !altered_tables.empty?
          error "Found altered meta table(s): #{altered_tables.join(', ')}"
        end

        # Create seed tables
        schema_list = conn.quote_list(schemas)
        meta_list = conn.quote_list(meta_tables.map(&:uid))
        conn.exec %(
          insert into prick.seed_tables (schema_name, table_name, value)
            select schema_name, table_name, value
            from prick.current_serials
            where schema_name in #{schema_list}
              and (schema_name || '.' || table_name) not in #{meta_list}
              and value > 1
        )
      end

      def to_s = "SEED #{schemas.join(', ')}"
    end


    class Sql < Node
      attr_reader :sql
      def initialize(sql) = super sql: sql
      def execute = conn.execute sql
      def to_s = "SQL #{sql.inspect}"
    end

    class Call < Node
      attr_reader :proc
      def initialize(proc) = super proc: proc
      def execute = conn.proc proc
      def to_s = "CALL #{proc}"
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
      def to_s = "FOX ..."
    end

    class RubyFile < File
      def execute = bash.command "echo TODO RUBY"
      def to_s = "RUBY #{file}"
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

    # TODO MERGE can't be used as a target for build or make. It is only used
    # by the 'prick merge' command

    # TODO
    #   copy_tables
    #   sync_tables
    #   prepare_tables
    #   handle_tables
    #
#   class Merge
#     def kind = self.classname.upcase.to_sym
#     attr_reader :kind # COPY, SYNC, PREPARE, HANDLE
#     attr_reader :table
#
#     # Only used by sync/prepare
#     attr_reader :key
#     attr_reader :id_table
#     attr_reader :sql
#   end

    # TODO Split into an object per table
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

    class MakeMeta < Node
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


