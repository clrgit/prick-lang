# frozen_string_literal: true

require_relative "./prick/version"

require 'pathname'
require 'set'
require 'stringio'
require 'time'

require 'constrain'
require 'forward_to'
require 'indented_io'
require 'string-text'

include ForwardTo
include Constrain
include IndentedIO

using String::Text

module Prick
  class Error < StandardError; end
  class InternalError < Error; end

  # Relative paths to subdirectories
  BIN_DIRNAME = "bin"
  SCHEMA_DIRNAME = "schema"
  SCHEMA_PRICK_DIRNAME = File.join(SCHEMA_DIRNAME, "prick")
  TEST_DIRNAME = "spec"
  LIB_DIRNAME = "lib"
  LIBEXEC_DIRNAME = "libexec"
  VAR_DIRNAME = "var"
  LOG_DIRNAME = File.join(VAR_DIRNAME, "log")
  STATE_DIRNAME = File.join(VAR_DIRNAME, "state")
  CACHE_DIRNAME = File.join(VAR_DIRNAME, "cache")
  SPOOL_DIRNAME = File.join(VAR_DIRNAME, "spool")
  BACKUP_DIRNAME = File.join(VAR_DIRNAME, "backup")
  DUMP_DIRNAME = File.join(VAR_DIRNAME, "dump")
  TMP_DIRNAME = "tmp"

  # Project subdirectories ([Symbol]). Keep in sync with project *_DIRNAMES!
  PROJECT_DIR_ATTRS = [
      :bin_dir, :schema_dir, :schema_prick_dir, :test_dir, :lib_dir, :libexec_dir, :var_dir, :log_dir,
      :state_dir, :cache_dir, :spool_dir, :backup_dir, :dump_dir, :tmp_dir
  ]

  # Project filename
  PROJECT_FILENAME = "prick.yml"

  # Default environment filename
  DEFAULT_ENVIRONMENT_FILENAME = "prick.environment.yml"

  # Default database state file
  DEFAULT_DATABASE_STATE_FILENAME = "database-state.yml"

  # Default prick state filename
  DEFAULT_COMPILER_STATE_FILENAME = "compiler-state.yml"

  # Default fox state filename
  DEFAULT_FOX_STATE_FILENAME = "fox-state.yml"

  # Default reflections filename
  DEFAULT_REFLECTIONS_FILENAME = "reflections.yml"

  # Prick SQL file. Lives in the schema/prick directory and builds the prick schema
  PRICK_SQL_FILENAME = "prick.sql"

  # Suffix for prick source files
  SOURCE_EXT = "prick"

  # Default source file ('make.prick'). Also used when including directories
  # (eg. './dir' becomes './dir/make.prick')
  DEFAULT_SOURCE_FILENAME = "make.#{SOURCE_EXT}"

  # State object
  def self.state = @@state
  def state = Prick.state

  # :call-seq
  #   self.initialize(**opts)
  #
  # See State for documentation of :opts
  #
  def self.initialize(**opts)
    # Create prick object
    @@state = State.new(**opts)
  end

  def self.error(msg) = ShellOpts.error msg
  def self.failure(msg) = ShellOpts.failure msg

  def error(msg) = Prick.error msg
  def failure(msg) = Prick.failure msg

private
  @@state = nil
end

require_relative './prick/state.rb'

require_relative './prick/lang.rb'
require_relative './prick/environment-lang.rb'
require_relative './prick/command.rb'

__END__
    # Ensure project directory
    case [!project_dir.nil?, File.directory?(project_dir)]
      in [false, false]
        ShellOpts.error "Can't find project directory #{project_dir}"
      in [false, true]
        File.exist? state.project_file or ShellOpts.error "Can't find #{state.project_file}"
      in [true, false]
        FileUtils.mkdir project_dir
      in [true, true]
        !File.exist? state.project_file or ShellOpts.error "Won't overwrite existing project"
    end

    Prick.module_eval do
      # Installation root directory
      const_set :PRICK_DIR, File.dirname(ShellOpts::program_path, 2)

      # Installation share directory
      const_set :PRICK_SHARE_DIR, "#{PRICK_DIR}/lib/prick/share"

      # The directory of the user process that invoked prick. Prick changes
      # directory while running the code so error messages has to be modified
      # relative to the environment of the user to make sense
      const_set :ENVIRONMENT_DIR, Dir.getwd

      # Project filename. This is the file that identifies a prick project directory
      const_set :PROJECT_FILENAME, "prick.yml"

      # Project directory. The default is to search upwards in the
      # directory hierarchy for the prick project file
      const_set :PROJECT_DIR, project_dir ||
          File.dirname(upfind(PROJECT_FILENAME, Dir.getwd)) or
              ShellOpts.error "Can't find prick project directory"

      # Prick project file
      const_set :PROJECT_FILE, File.join(PROJECT_DIR, PROJECT_FILENAME)

      # Project sub-directories
      const_set :PROJECT_DIRS, [
        const_set(:BIN_DIR, File.join(PROJECT_DIR, "bin")),
        const_set(:SCHEMA_DIR, File.join(PROJECT_DIR, "schema")),
        const_set(:SCHEMA_PRICK_DIR, File.join(SCHEMA_DIR, "prick")),
        const_set(:TEST_DIR, File.join(PROJECT_DIR, "spec")),
        const_set(:LIB_DIR, File.join(PROJECT_DIR, "lib")),
        const_set(:LIBEXEC_DIR, File.join(PROJECT_DIR, "libexec")),
        const_set(:VAR_DIR, File.join(PROJECT_DIR, "var")),
        const_set(:LOG_DIR, File.join(VAR_DIR, "/log")),
        const_set(:STATE_DIR, File.join(VAR_DIR, "/state")),
        const_set(:CACHE_DIR, File.join(VAR_DIR, "/cache")),
        const_set(:SPOOL_DIR, File.join(VAR_DIR, "/spool")),
        const_set(:BACKUP_DIR, File.join(VAR_DIR, "/backup")),
        const_set(:DUMP_DIR, File.join(VAR_DIR, "/dump"))
      ]

      # State filename
      const_set :DEFAULT_STATE_FILENAME, ".prick.state.yml"
      const_set :STATE_FILE, state_file || File.join(STATE_DIR, DEFAULT_STATE_FILENAME)

      # Version file
      const_set :VERSION_FILENAME, "version.yml"
      const_set :VERSION_FILE, File.join(SCHEMA_PRICK_DIR, VERSION_FILENAME)

      # Database
      const_set :PRICK_USERNAME, username
      const_set :PRICK_DATABASE, database
      const_set :PRICK_ENVIRONMENT, environment

    end
