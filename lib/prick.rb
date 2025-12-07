# frozen_string_literal: true

require_relative "./prick/version"

require 'pathname'
require 'set'
require 'stringio'
require 'time'

require 'constrain'
require 'forward_to'
require 'indented_io'
require 'pg_conn'
require 'string-text'

include ForwardTo
include Constrain
include IndentedIO

using String::Text

module Prick
  class Error < StandardError; end
  class InternalError < Error; end

  # Time constants
  EPOCH = "1970-01-01 00:00:00 UTC"
  EPOCH_TIMESTAMP = Time.parse(EPOCH)
  TIMESTAMP_FMT ="%Y-%m-%d %H:%M:%S %Z"

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

  # prick.yml
  # prick.environment.yml
  #
  # var
  #   lib
  #     gryf
  #       database.yml
  #       build-cache.yml
  #       compiler-spool.yml
  #       fox-spool.yml
  #
  #     mikras-production
  #       database.yml
  #       build-cache.yml
  #       compiler-spool.yml
  #       fox-spool.yml
  #
  #   log
  #     prick.log
  #     gryf
  #       gryf.log
  #
  #   database  # database name. Database setup is then in ./var/$database/database.yml
  #             # database.yml should not contain database name - it is derived from its
  #             # containing directory - so it is easy to rename databases
  #

  # Project subdirectories ([Symbol]). Keep in sync with project *_DIRNAMES!
  PROJECT_DIR_ATTRS = [
      :bin_dir, :schema_dir, :schema_prick_dir, :test_dir, :lib_dir, :libexec_dir, :var_dir, :log_dir,
      :state_dir, :cache_dir, :spool_dir, :backup_dir, :dump_dir, :tmp_dir
  ]

  # Project filename
  PROJECT_FILENAME = "prick.yml"

  # Version filename
  VERSION_FILENAME = "version.yml"

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

  # List of SQL files that defines objects in the prick schema. Only prick.sql
  # is mandatory
  PRICK_BUILD_FILENAMES = %w(prick.sql tables.sql views.sql functions.sql)

  # Settings object
  def self.settings = @@settings
  def settings = Prick.settings

  # :call-seq
  #   self.initialize(**opts)
  #
  # See Settings for documentation of :opts
  #
  def self.initialize(**opts, &block)
    # Initialize Settings
    @@settings = Settings.new(**opts, &block)
  end

  def self.error(msg) = ShellOpts.error msg
  def self.failure(msg) = ShellOpts.failure msg

  def error(msg) = Prick.error msg
  def failure(msg) = Prick.failure msg

private
  @@state = nil
end

require_relative './prick/bash.rb'
require_relative './prick/git.rb'
require_relative './prick/ansi.rb'

require_relative './prick/database.rb'
require_relative './prick/settings.rb'

require_relative './prick/lang.rb'
require_relative './prick/environment-lang.rb'
require_relative './prick/command.rb'

