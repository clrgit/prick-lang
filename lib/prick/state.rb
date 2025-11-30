
require_relative '../ext/x_fileutils.rb'

module Prick
  class State
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

    # Each project subdirectory
    attr_reader *Prick::PROJECT_DIR_ATTRS

    #
    # F I L E S
    #

    # 'prick.yml' project file
    attr_reader :project_file

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

    # Project version from PRICK.VERSIONS. Initialized when connecting to the database
    attr_accessor :database_version

    # Prick version from PRICK.VERSIONS. Initialized when connecting to the database
    attr_accessor :database_prick_version

    # Environment from PRICK.VERSIONS. Initialized when connecting to the database
    attr_accessor :database_environment

    # Timestamp from PRICK.VERSIONS
    attr_accessor :database_timestamp

    #
    # E N V I R O N M E N T S
    #

    # Map from environment name (String) to environment object
    attr_reader :environments

    # Name of current environment. If not set in the state file, the enviroment
    # is read from the database when the first connection is established by the
    # #connection method. Use '#environments[environment]' to get the
    # corresponding Environment object
    def environment() @environment end
    def environment=(env)
      constrain env, String, nil
      env.nil? || environments.key?(env) or raise "Illegal environment: '#{env}'"
      @environment = env
    end

    #
    # I N I T I A L I Z E
    #

    # We assume that we are somewhere in the project directory hierarchy if
    # :project_dir is nil
    def initialize(
        project_dir: nil,
        environment_file: nil, reflections_file: nil,
        database_state_file: nil, compiler_state_file: nil, fox_state_file: nil,
        **attrs)

      # Set installation and user directories
      @prick_dir = File.dirname ShellOpts.program_path, 2
      @prick_share_dir = "#{@prick_dir}/lib/prick/share"
      @environment_dir = ShellOpts.environment_path

      # Search for project file if not given, stop initialization if not found
      @project_dir = project_dir || FileUtils.upfind(Prick::PROJECT_FILENAME) or
          Prick.error "Can't find #{Prick::PROJECT_FILENAME)

      # Assign subdirectories
      @project_dirs = Prick::PROJECT_DIR_ATTRS.map { |attr|
        var = :"@#{attr}"
        val = const_get(attr.upcase)
        self.instance_variable_set(var, File.join @project_dir, val)
      }

      # Assign files using helper method for brevity
      @project_file = File.join @project_dir, Prick::PROJECT_FILENAME
      @environment_file = file_attr environment_file, Prick::DEFAULT_ENVIRONMENT_FILENAME
      @reflections_file = file_attr reflections_file, Prick::DEFAULT_ENVIRONMENT_FILENAME
      @database_state_file = file_attr database_state_file, Prick::DEFAULT_DATABASE_STATE_FILENAME
      @compiler_state_file = file_attr compiler_state_file, Prick::DEFAULT_COMPILER_STATE_FILENAME
      @fox_state_file = file_attr fox_state_file, Prick::DEFAULT_FOX_STATE_FILENAME
      @prick_sql_file = File.join @schema_prick_dir, Prick::PRICK_SQL_FILENAME

      # Load project, environment, state, and version files. Ignores absent files
      load_files if project_dir

      # Assign additional attributes
      attrs.each { |attr, value| self.send(:"#{attr}=", value) }

      # Connect to database using promise if defined and present and requested (the default) using an option
      # TODO
    end

    #
    # S T A T E   H A N D L I N G
    #

    def load_project = load_file @project_file, PROJECT_FILE_FIELDS
    def save_project(**opts) = save_file @project_file, PROJECT_FILE_FIELDS, **opts

    def load_environment
      return nil if !File.exist? environment_file
      hash = YAML.load_extended environment_file
      @environments = EnvironmentLang.compile(hash)
      @environment_loaded = true
    end

    def load_database_state = load_file @database_state_file, DATABASE_STATE_FILE_FIELDS
    def save_database_state(**opts) = save_file @database_state_file, DATABASE_STATE_FILE_FIELDS, **opts

    def load_version = load_file @version_file, VERSION_FILE_FIELDS
    def save_version(**opts) = save_file @version_file, VERSION_FILE_FIELDS, **opts

    def load_files() load_project; load_environment; load_version; load_state end
    def save_files() save_project; save_version; save_state end

  private
    PROJECT_FILE_FIELDS = [:name, :title, :prick_version]
    DATABASE_STATE_FILE_FIELDS = [:database, :username, :environment]
    VERSION_FILE_FIELDS = [:version]

    # Return absolute path of val if defined, default is
    # '#@project_dir/default'. Used to initialize *_file attributes
    def set_file_attr(val, default) = val.nil? ? File.join(@project_dir, default) : File.absolute_path(val)

    def load_file(file, fields)
      return nil if !File.exist? file
      h = YAML.load_extended(file)
      fields.each { |field| self.instance_variable_set(:"@#{field}", h[field]) }
    end

    def save_file(file, fields, **opts)
      data = fields.map { |field| [field, opts.key?(field) ? opts[field] : send.send(field)] }.to_h
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
