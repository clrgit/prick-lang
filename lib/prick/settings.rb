
require_relative './ext/x_fileutils.rb'
require 'concurrent'

require_relative './lang/timer.rb'
include Prick::Lang::Timer

module Prick
  class Settings
    #
    # D I R E C T O R I E S
    #

    # Prick installation directory
    attr_reader :prick_dir

    # Prick instalation share directory
    attr_reader :prick_share_dir

    # User environment dir (the current directory when prick was called). Used
    # make paths in error messages relative to the current directory
    attr_reader :environment_dir

    # Project dir. Top-level project directory
    attr_reader :project_dir

    # List of project subdirectories
    attr_reader :project_dirs

    # Each project subdirectory. :bin_dir, :schema_dir, ...
    attr_reader *Prick::PROJECT_DIR_ATTRS

    #
    # F I L E S
    #

    # Initial 'make.prick' file
    attr_reader :prick_file

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

    # Database state file. Default '#@state_dir/database-state.yml'
    attr_reader :database_state_file

    # Compiler state file. Default '#@state_dir/compiler-state.yml'
    attr_reader :compiler_state_file

    # Fox state file. Default '#@state_dir/fox.yml'
    attr_reader :fox_state_file

    # Prick SQL file. Builds the prick schema
    attr_reader :prick_sql_file

    # List of file attributes to load
    attr_reader :load_files

    # List of file attributes to save
    attr_reader :save_files

    #
    # P R O J E C T   A T T R I B U T E S
    #

    # Project identifier. Used as default for database, username etc.
    attr_accessor :name

    # Project title. Capitalized name of project. Default @name.capitalize
    attr_accessor :title

    # Project version
    attr_accessor :version

    # Version of prick. Note that this can be different than the current
    # version of prick
    attr_accessor :prick_version

    #
    # D A T A B A S E   A T T R I B U T E S
    #

    # Database name. nil if state file is absent
    attr_accessor :database

    # Database owner name. Typically the same as the database name. nil if
    # database is absent
    attr_accessor :username

    # Name of current environment. If not set in the state file, the enviroment
    # is read from the database when the first connection is established by the
    # #connection method. Use '#environments[environment]' to get the
    # corresponding Environment object
    attr_accessor :environment

    #
    # B U I L D   S T A T E
    #

    # Database build state. Initialized by #load_build_state
    attr_accessor :build # PRICK.STATES Struct object

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

    # Start creating super_conn in an independent thread
    def promise_super_conn
      @super_conn_promise ||= Concurrent::Promise.execute do
        PgConn.new("postgres")
      end
    end

    # Start creating user_conn in an independent thread
    def promise_user_conn
      @user_conn_promise ||= Concurrent::Promise.execute do
        PgConn.new(database, username)
      end
    end

    # Superuser connection. Use promise if present
    def super_conn = @super_conn ||= promise_super_conn.value

    # User (database owner) connection. Use promise if present
    def user_conn = @user_conn ||= promise_user_conn.value

    # The user connection if defined, otherwise the superuser connection. Used
    # when any connection to the database will do
    def conn = @user_conn || super_conn

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
        environment_file: nil, reflections_file: nil,
        database_state_file: nil, compiler_state_file: nil, fox_state_file: nil,
        load_files: [:project_file, :version_file], # :project_file is always loaded if present on disk
        save_files: [],
        super_conn: false, user_conn: false,
        **attrs)

      # TODO
      #   ...
      #   use_super_conn: false,
      #   use_conn: false
      #

      # Set installation and user directories
      @prick_dir = File.dirname ShellOpts.program_path, 2
      @prick_share_dir = "#{@prick_dir}/lib/prick/share"
      @environment_dir = ShellOpts.environment_path

      # Search for project file if not given, stop initialization if not found
      @project_dir = project_dir || FileUtils.upfinddir(Prick::PROJECT_FILENAME) or
          Prick.error "Can't find #{Prick::PROJECT_FILENAME}"

      # Assign subdirectories
      @project_dirs = Prick::PROJECT_DIR_ATTRS.map { |attr|
        var = :"@#{attr}"
        val = Prick.const_get(attr.to_s.upcase + "NAME")
        self.instance_variable_set(var, File.join(@project_dir, val))
      }

      # Assign files using #file_attr helper method for brevity
      @prick_file = File.join schema_dir, Prick::DEFAULT_SOURCE_FILENAME
      @project_file = File.join @project_dir, Prick::PROJECT_FILENAME
      @version_file = File.join schema_prick_dir, Prick::VERSION_FILENAME
      @environment_file = file_attr environment_file, @project_dir, Prick::DEFAULT_ENVIRONMENT_FILENAME
      @reflections_file = file_attr reflections_file, schema_dir, Prick::DEFAULT_ENVIRONMENT_FILENAME
      @database_state_file = file_attr database_state_file, state_dir, Prick::DEFAULT_DATABASE_STATE_FILENAME
      @compiler_state_file = file_attr compiler_state_file, state_dir, Prick::DEFAULT_COMPILER_STATE_FILENAME
      @fox_state_file = file_attr fox_state_file, state_dir, Prick::DEFAULT_FOX_STATE_FILENAME
      @prick_sql_file = File.join @schema_prick_dir, Prick::PRICK_SQL_FILENAME

      # Register state files to load/save
      @load_files = ([:project_file, :version_file] + load_files).uniq
      @save_files = save_files

      # Load state files. Absent files are ignored
      load_state_files

      # Start connection promises if required
      promise_super_conn if super_conn
      promise_user_conn if user_conn && @database

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

    def load_environments
      return nil if environment_file.nil? || !File.exist?(environment_file)
      hash = YAML.load_extended environment_file
      @environments = EnvironmentLang.compile(hash)
      @environment_loaded = true
    end

    def load_database_state = load_file :database_state_file
    def save_database_state(**opts) = save_file :database_state_file, **opts

    def load_compiler_state
      data = File.exist?(state_file) ? YAML.load_extended(state_file) : {}
      @timestamp ||= Time.parse(data[:timestamp] || Prick::EPOCH)
      @completed_resources = data[:completed_resources] || []
    end

    def save_compiler_state
      File.write state_file, {
        timestamp: Time.now.strftime(Prick::TIMESTAMP_FMT),
        completed_resources: @completed_resources
      }.to_yaml
    end


    def load_state_files = @load_files.each { |attr| load_file(attr) }
    def save_state_files(**opts) = @save_files.each { |attr| save_file(attr, **opts) }

    # Load status of last build from the PRICK.STATES view (that builds on the
    # PRICK.BUILDS table)
    def load_build_state
      @build = conn.struct "select * from prick.states limit 1"
    end

    # Save status of last build to the PRICK.BUILDS table
    def save_build_state(status: nil)
      user_conn.insert "prick.builds",
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
    end

  private
    attr_writer :verbose, :dryrun, :log

    # Map from state file attribute to list of fields
    STATE_FILES = {
      project_file: [:name, :title, :prick_version],
      database_state_file: [:database, :username, :environment],
      version_file: [:version]
    }

    # List of active state file attributes (Symbol). Active state files are
    # both loaded and saved, while inactive files are only saved
    attr_reader :active_files

    # Return absolute path of val if defined, default is
    # '#@project_dir/default'. Returns nil if false. Used to initialize *_file
    # attributes
    def file_attr(val, *default) = val.nil? ? File.join(*default) : File.absolute_path(val)

    def load_file(attr)
      return load_environments if attr == :environment_file
      file = self.send(attr)
      return nil if file.nil? || !File.exist?(file)
      h = YAML.load_extended(file)
      STATE_FILES[attr].each { |field| self.instance_variable_set(:"@#{field}", h[field]) }
    end

    def save_file(attr, **opts)
      file = self.send(attr)
      return nil if file.nil?
      data = STATE_FILES[attr].map { |field| [field, opts.key?(field) ? opts[field] : self.send(field)] }.to_h
      IO.write file, data.to_yaml
    end
  end
end




__END__

    def load_compiler_state_file
      data = File.exist?(compiler_state_file) ? YAML.load_extended(compiler_state_file) : {}
      @timestamp ||= Time.parse(data[:timestamp] || "1970-01-01 00:00:00 UTC")
      @completed_resources = data[:completed_resources] || []
    end

    def save_compiler_state_file
      File.write state_file, {
        timestamp: Time.now.strftime("%Y-%m-%d %H:%M:%S %Z"),
        completed_resources: @completed_resources
      }.to_yaml
    end

__END__


    PROJECT_FILE_FIELDS = {
      title: :PROJECT_TITLE,
      name: :PROJECT_NAME,
      prick_version: :PRICK_VERSION,
    }

    STATE_FILE_FIELDS = {
      database: :PRICK_DATABASE,
      username: :PRICK_USERNAME,
      environment: :PRICK_ENVIRONMENT,
    }

    VERSION_FILE_FIELDS = {
      version: :PROJECT_VERSION
    }


  def self.load_project = load_file PROJECT_FILE, PROJECT_FILE_FIELDS
  def self.save_project(**opts) = save_file PROJECT_FILE, PROJECT_FILE_FIELDS, **opts

  def self.load_version = load_file VERSION_FILE, VERSION_FILE_FIELDS
  def self.save_version(**opts) = save_file VERSION_FILE, VERSION_FILE_FIELDS, **opts

  def self.load_state = load_file STATE_FILE, STATE_FILE_FIELDS
  def self.save_state(**opts) = save_file STATE_FILE, STATE_FILE_FIELDS, **opts




      @project_file = project_file || File.join(prick_dir, PROJECT_FILENAME)
      @state_file = proj


      , @environment_file,
      @reflections_file, @state_file, @fox_state_file =
          project_file, environment_file, reflections_file, state_file, fox_state_file

      @project_loaded = @state_loaded = @environment_loaded = false

      if @project_file && File.exist?(@project_file)
        load_project_file
        load_state_file if @state_file && File.exist?(@state_file)
      end

      # FIXME The environment file should be loaded on-demand but it is hard to
      # do when the environments are accessed through a class-interface
      load_environment_file if @environment_file && File.exist?(@environment_file)
    end




  end
end
