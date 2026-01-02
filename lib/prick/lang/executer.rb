
module Prick::Lang
  # TODO
  #   Handle schema commands
  #   Collect fox files
  #
  class Executer < CompilerProcess
    using String::Text

    attr_reader :bash # Bash::Bash object
    attr_reader :source # Executed postgres source if settings.log? is true

    def initialize
    end

#   logger = lambda { |arg| dst.puts arg.sub(/\n\s*\n/m, "\n") + ";" }
#   def logger(msg) puts  msg.sub(/\n\s*\n/m, "\n") end

    def execute
      # We delay initialization of the Bash object until here because we can't
      # access the #compiler object from #initialize
      @bash = Bash::Bash.new(bash_environment)
      @source = nil

      # Setup unit objects for #execute
      Unit::Node.conn = conn
      Unit::Node.bash = @bash

      # Create new PRICK.BUILDS record

p :BING
      # Clear PRICK.RESOURCES that are marked for rebuild

      # Setup logger
      proc = lambda { |arg| $stderr.puts arg.sub(/\n\s*\n/m, "\n") + ";" }
      logger = settings.log? && !conn.log? ? proc : nil

      # Execute units
      conn.with(log: logger) {
        units.each { |unit|
          unit.execute
        }
      }

      # Save compiler state

#     puts "after"
#     p conn.tuples "prick.resources"
    end

    def inspect = "#<#{self.class} ...>"

  private
    # Singleton bash(1) environment (Hash). It is injected into the enviroment
    # of subprocesses
    def bash_environment
      @@BASH_ENVIRONMENT ||= begin
        # Path
        hash = { "PATH" => settings.executable_search_path }

        # Directories
        hash.merge({
          "PRICK_DIR" => settings.project_dir,
          "PRICK_DATABASE_CACHEDIR" => settings.database_cache_dir
        })

        # Directories from settings.dirs
        Prick::PROJECT_DIR_ATTRS.each { |attr| hash["PRICK_#{attr.upcase}DIR"] = settings.dirs[attr] }

        # Simple attributes
        attrs = [:name, :title, :version, :database, :username, :environment, :verbose?, :dryrun?, :log?]
        for attr in attrs
          hash["PRICK_#{attr.to_s.sub("?", "").upcase}"] = settings.send(attr).to_s
        end

        # Timestamp
        hash["PRICK_TIMESTAMP"] = settings.created_at.strftime("%F %T %Z")

        # Targets
        hash["PRICK_TARGETS"] = compiler.targets.join(" ")

        # Final result
        hash

#       TODO
#       # PRICK_ENVIRONMENT_* variables. Only defined if the environment is known
#       if !Prick.state.environment.nil? && environments.key?(environment)
#         hash.merge! environments[environment].bash_environment
#       end
      end
    end

    @@BASH_ENVIRONMENT = nil
  end
end

__END__
#         @idr = nil
#         case @unit
#           when Unit::DetectMeta
#             detect_meta_command
#           when Unit::SchemaCommand
#             schema_command
#           when Unit::SearchPath
#             search_path_command
#           else
#             case @idr = @unit.node
#               when Idr::SqlCommand
#                 sql_command(@idr.source.value)
#               when Idr::FoxFileCommand
#                 fox_command(@idr.path)
#               when Idr::FileCommand
#                 file_command(@idr.path)
#               when Idr::ExternalCommand
#                 idr.kind == :EXEC ? exec_command(@idr.source.value) : eval_command(@idr.source.value)
#               when Idr::CopyCommand
#                 copy_command @idr.tables.map(&:value)
#               when Idr::SyncCommand
# #               sync_command @idr.table, @idr.key, @idr.id_table || @idr.source.value
#                 sync_command
#               when Idr::PrepareCommand
# #               prepare_command @idr.table, @idr.key, @idr.id_table || @idr.source.value
#                 prepare_command
#               when Idr::MarkCommand
#                 mark_command
#               else
#                 puts "Oops #{@unit.node.class}"
#             end
#         end
    # Current unit
    attr_reader :unit

    # Current schema (may be nil)
    def schema_name = unit.schema_name

    # Current idr
    attr_reader :idr

    def commit_command
      run "COMMIT" do conn.commit end
    end

    # Unit operations
    def detect_meta_command
      commit_command
      run "DETECT META" do conn.proc :"prick.detect_meta" end
    end

    def schema_command
      case unit.command
        when :recreate
          run "RECREATE #{schema_name}" do
            conn.schema.drop schema_name, cascade: true
            conn.schema.create schema_name
          end
        when :drop
          run "DROP #{schema_name}" do
            conn.schema.drop schema_name, cascade: true
          end
      end
    end

    def search_path_command
      run "SEARCH PATH #{schema_name}" do conn.search_path = schema_name end
    end

    # Idr operations
    def exec_command(cmd)
      commit_command
      run "EXEC", cmd do system(cmd) end
    end

    def eval_command(cmd)
      commit_command
      run "EVAL", cmd do system(cmd) end
    end

    def sql_command(source)
      run "SQL", source do conn.exec(source) end
    end

    def file_command(filename)
      run "FILE #{filename}" do sql(IO.read filename) end
    end

    def fox_command(filename)
      commit_command
      run "FOX #{filename}" do
        system("fox -d #{prick_database} -U #{prick_username} \#{files}")  # FIXME
      end
    end

    def copy_command(tables)
      commit_command
      run "COPY #{tables.join(', ')}" do system("pg-merge copy ...") end
    end

    def sync_command
      commit_command
      run "SYNC" do system("pg-merge sync ...") end
    end

    def prepare_command
      commit_command
      run "PREPARE" do system("pg-merge prepare ...") end
    end

    def mark_command
      log "MARK #{idr.uid}" do compiler.add_completed_resource idr.uid end
    end

    def run(*msg, &block)

      log *msg
#     yield if !compiler.dryrun
    end

    def log(s, t = "")
      if compiler.log?
        puts s
        indent { puts t } if !t.empty?
      end
    end

