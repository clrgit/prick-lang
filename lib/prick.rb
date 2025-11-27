# frozen_string_literal: true

require_relative "./prick/version"

require 'pathname'
require 'set'
require 'stringio'
require 'time'
require 'yaml'

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

  # :call-seq
  #   self.initialize(project_dir: nil, state_file: nil = nil, new: false)
  #
  # Define constants, ensure and and change to project directory. All path
  # related constants are absolute paths
  #
  # :project_dir is only not-nil when running 'prick init'
  def self.initialize(database: nil, username: nil, environment: nil, project_dir: nil, state_file: nil)
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

    # Ensure project directory
    case [!project_dir.nil?, File.exist?(PROJECT_DIR)]
      in [false, false]
        ShellOpts.error "Can't find project directory #{PROJECT_DIR}"
      in [false, true]
        File.exist? PROJECT_FILE or ShellOpts.error "Can't find #{PROJECT_FILE}"
      in [true, false]
        FileUtils.mkdir project_dir
      in [true, true]
        !File.exist? PROJECT_FILE or ShellOpts.error "Won't overwrite existing project"
    end

    # Load runtime information
    load_files if project_dir.nil?

    # Switch to project directory
    Dir.chdir PROJECT_DIR
  end

  def self.load_files
    load_project
    load_version
    load_state
  end

  def self.save_files
    save_project
    save_version
    save_state
  end

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

private
  def self.upfind(file, dir = ShellOpts.environment_path)
    while dir != "/" && !File.exist?(File.join dir, file)
      dir = File.dirname(dir)
    end
    if dir == "/" # RSpec compatibility
      dir = "" if defined?(RSpec)
    end
    dir == "/" ? nil : File.join(dir, file)
  end

  def self.load_file(file, fields)
    return nil if !File.exist? file
    h = YAML.load_file(file, symbolize_names: true)
    fields.each { |field, const| const_set(const, h[field]) }
  end

  def self.save_file(file, fields, **opts)
#   p file
#   p fields
#   p opts
    data = fields.map { |field, const|
      [field, opts.key?(field) ? opts[field] : Prick.const_get(const)]
    }.to_h
    IO.write file, data.to_yaml
  end
end

require_relative './prick/lang.rb'
require_relative './prick/command.rb'

