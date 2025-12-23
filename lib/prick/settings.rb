
require_relative './ext/x_fileutils.rb'
require_relative './ext/x_yaml.rb'

module Prick
  class Settings
    #
    # U S E R   D I R E C T O R Y
    #

    # User environment dir (the current directory when prick was called). Used
    # make paths in error messages relative to the current directory
    attr_reader :user_dir

    #
    # P R I C K   I N S T A L L A T I O N   D I R E C T O R I E S
    #

    # Prick installation directory
    attr_reader :prick_dir

    # Prick installation share directory
    attr_reader :prick_share_dir

    #
    # P R O J E C T   D I R E C T O R I E S
    #

    # Project dir. Top-level project directory
    attr_reader :project_dir

    # Database cache dir
    attr_reader :database_cache_dir

    # Struct with project subdirectories as members: :bin, :lib, :var, ... but
    # not the per-database directory database_cache_dir
    attr_reader :dirs

    #
    # F I L E S
    #

    # Initial 'make.prick' file
    attr_reader :make_file

    # 'prick.yml' project file
    attr_reader :project_file

    # 'version.yml' file
    attr_reader :version_file

    # 'prick.environment environment file. Note that the file can be absent if
    # the project doesn't use environments
    attr_reader :environment_file

    # Reflections file. Default '#@schema_dir/reflections.yml'. May be nil if the
    # file is absent
    attr_reader :reflections_file

    # Prick state file
    attr_reader :prick_state_file

    # Database state file. Default '#@state_dir/database-state.yml'
    attr_reader :database_state_file

    # List of all database state files.
    def database_state_files() = @database_state_files ||= Dir.glob(database_state_file_glob)

    # Compiler state file. Default '#@state_dir/compiler-state.yml'
    attr_reader :compiler_state_file

    # Fox state file. Default '#@state_dir/fox.yml'
    attr_reader :fox_state_file

    # Prick SQL file. Builds the prick schema
    attr_reader :prick_sql_file

    #
    # P R O J E C T   A T T R I B U T E S
    #

    # Project identifier. Read from prick.yml
    attr_accessor :name

    # Project title. Defaults to @name.capitalize. Read from prick.yml
    attr_accessor :title

    # Project version. Read from schema/prick/version.yml
    attr_accessor :version

    # Version of prick. Note that this can be different from the current
    # version of prick. Read from var/<database>/states.yml
    attr_accessor :prick_version

    #
    # D A T A B A S E   A T T R I B U T E S
    #

    # Database name. nil if state file is absent
    attr_accessor :database

    # Database owner name (a postgres user). Always the same as the name of the
    # database
    alias_method :username, :database

    # Superuser name. It is only set on the command line, defaults to the
    # current user
    attr_accessor :superuser

    # Name of current environment. If not set in the database state file, it is
    # read from the database the enviroment.  Use '#environments[environment]'
    # to get the corresponding Environment object
    attr_accessor :environment

    #
    # B U I L D   S T A T E
    #

    # Last database build state. Read from database
    attr_accessor :database_state # PRICK.STATES Struct object

    # Map from database name to state for all cached databases. Should be
    # explicitly loaded using #load_database_states
    attr_reader :database_states

    # Dir glob matching all database state files
    attr_reader :database_state_file_glob

    #
    # E N V I R O N M E N T S
    #

    # Map from environment name to environment object
    attr_reader :environments # {String => Environment}

    #
    # G I T
    #

    # Git branch
    def branch() @branch ||= Git.branch.current end

    # Git revision (commit ID)
    def rev(kind: :long)
      case kind
        when :short; @rev_short ||= rev()[0...8]
        when :long; @rev_long ||= Git.id
      end
    end

    # True if the git repository is clean (not modified)
    def clean?()
      return @clean if defined?(@clean)
      @clean = Git.clean?
    end

    #
    # C O N N E C T I O N S
    #

    # Superuser connection to the postgres default database
    def system_conn = @system_conn ||= PgConn.new("postgres", superuser)

    # Superuser connection to the current database
    def super_conn = @super_conn ||= PgConn.new(database, superuser)

    # User (database owner) to the current database
    def user_conn = @user_conn ||= PgConn.new(database, username)

    #
    # R U N T I M E   O P T I O N S
    #

    def verbose? = @verbose
    def dryrun? = @dryrun
    def log? = @log

    #
    # T I M E S T A M P S
    #

    # Time when the program started
    @@created_at = Time.now
    def created_at = @@created_at

    # Duration of the compile and execute phases. Read from the connection build object
    attr_accessor :compile_duration
    attr_accessor :execute_duration

    #
    # I N I T I A L I Z E
    #

    # We assume that we are somewhere in the project directory hierarchy if
    # :project_dir is nil.
    #
    # If a file argument is true, the default value is used and the file will be loaded and saved. If false,
    # it is set to nil. Note that non-existing files are ignored so set it to
    # false only when the file is irrelevant for the current command (eg.
    # 'prick setup' doesn't need to read the reflections file)
    #
    def initialize(
        project_dir: nil,
        database: nil,
        **attrs)

      # Set prick installation directories
      @prick_dir = File.dirname ShellOpts.program_path, 2
      @prick_share_dir = "#{@prick_dir}/lib/prick/share"
      @prick_libexec_dir = "#{@prick_dir}/libexec"

      # Register current directory
      @user_dir = ShellOpts.environment_path

      # Search for project file if not given, stop initialization if not found
      @project_dir = project_dir || FileUtils.upfinddir(Prick::PROJECT_FILENAME) or
          Prick.error "Can't find #{Prick::PROJECT_FILENAME}"

      # Assign subdirectories
      @dirs = OpenStruct.new \
          Prick::PROJECT_DIR_ATTRS.map { |attr|
            val = Prick.const_get(attr.to_s.upcase + "_DIRNAME")
            [attr, File.join(@project_dir, val)]
          }.to_h
      @dirs.project = @project_dir

      # Assign executable path
      @executable_search_path = [@dirs.bin_dir, @dirs.libexec_dir, ENV['PATH']].join(':')

      # Assign global prick files using #file_attr helper method for brevity
      @project_file = File.join dirs.project, Prick::PROJECT_FILENAME
      @version_file = File.join dirs.prick_schema, Prick::VERSION_FILENAME
      @prick_state_file = File.join dirs.project, Prick::PRICK_STATE_FILENAME
      @environment_file = file_attr environment_file, dirs.project, Prick::ENVIRONMENT_FILENAME
      @reflections_file = file_attr reflections_file, dirs.schema, Prick::REFLECTIONS_FILENAME
      @make_file = File.join dirs.schema, Prick::SOURCE_FILENAME
      @prick_sql_file = File.join dirs.prick_schema, Prick::PRICK_SQL_FILENAME

      # Assign database state glob
      @database_state_file_glob = File.join dirs.project, Prick::DATABASE_STATE_FILE_GLOB

      # Load state files. Absent files are ignored
      load_project
      load_version

      # Set database
      if database
        @database = database
      else
        load_prick_state
      end

      # Per-database settings
      if @database
        @dirs.database_cache = File.join(Prick::CACHE_DIRNAME, @database)

        # Assign database cache files
        @database_state_file = file_attr database_state_file, dirs.database_cache, Prick::DATABASE_STATE_FILENAME
        @compiler_state_file = file_attr compiler_state_file, dirs.database_cache, Prick::COMPILER_STATE_FILENAME
        @fox_state_file = file_attr fox_state_file, dirs.database_cache, Prick::FOX_STATE_FILENAME

        # Load database state from file. Compiler and fox states are loaded elsewhere
        load_database_state
      end

      # Assign additional attributes
      attrs.each { |attr, value| self.send(:"#{attr}=", value) }
    end

    #
    # S T A T E   H A N D L I N G
    #

    def load_project = load_file :project_file
    def save_project(**opts) = save_file :project_file, **opts

    def load_version = load_file :version_file
    def save_version(**opts) = save_file :version_file, **opts

    def load_prick_state = load_file :prick_state_file
    def save_prick_state(**opts) = save_file :prick_state_file, **opts

    def load_environments
      return nil if environment_file.nil? || !File.exist?(environment_file)
      hash = YAML.load_extended environment_file
      @environments = EnvironmentLang.compile(hash)
      @environment_loaded = true
    end

    # Load database state from cache file
    def load_database_state
      @database_state = load_file :database_state_file
    end

    # Write build state to cache file
    def save_database_state
      IO.write database_state_file, @database_state.to_h.to_yaml_extended
    end

    # Load database state from database
    def get_database_state
      @database_state = user_conn.struct "select * from prick.states limit 1"
      @environment = @database_state.environment
    end

    # Set database state and save to database
    def set_database_state(status: nil)
      @database_state = OpenStruct.new \
        name: name,
        environment: environment,
        version: version,
        branch: branch,
        rev: rev(kind: :short),
        clean: clean?,
        status: status,
        prick_version: prick_version,
        created_at: created_at,
        compile_duration: compile_duration,
        execute_duration: execute_duration

      id = user_conn.insert "prick.builds", **@database_state.to_h
      @database_state.id = id
    end

    # Load all database states
    def load_database_states
      @database_states = database_state_files.map { |file|
        [File.basename(File.dirname(file)), OpenStruct.new(YAML.load_extended(file))]
      }.to_h
    end

#   def reset_database_state
#     @environment = nil
#     @clean = nil
#     @status = nil
#     @compile_duration = nil
#     @execute_duration = nil
#   end

    #
    # I O
    #

    def inspect = "Prick::Settings<...>"

  private
    attr_writer :verbose, :dryrun, :log

    # Map from state file attribute to list of fields or to a Class that can be
    # initialized with a single hash argument (eg. OpenStruct)
    STATE_FILES = {
      project_file: [:name, :title, :prick_version],
      version_file: [:version],
      prick_state_file: [:database],
      database_state_file: OpenStruct
    }

    # Return absolute path of val if defined, default is
    # '<project_dir>/<default-arguments>'. Used to initialize *_file attributes
    def file_attr(val, *default) = val.nil? ? File.join(@project_dir, *default) : File.absolute_path(val)

    def load_file(attr_or_file)
      if attr_or_file.is_a?(Symbol)
        attr = attr_or_file
        return load_environments if attr == :environment_file
        file = self.send(attr)
      else
        file = attr_or_file
      end
      return nil if file.nil? || !File.exist?(file)
      h = YAML.load_extended(file)
      case data = STATE_FILES[attr]
        when Array; data.each { |field| self.instance_variable_set(:"@#{field}", h[field]) }
        when Class; data.new(h)
      else
        internal "Unspecified file '#{attr}'"
      end
    end

    def save_file(attr, **opts)
      file = self.send(attr)
      return nil if file.nil?
      data = STATE_FILES[attr].map { |field| [field, opts.key?(field) ? opts[field] : self.send(field)] }.to_h
      IO.write file, data.to_yaml_extended
    end
  end
end


