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

  # prick.yml
  # prick.environment.yml
  # .prick.state.yml # Contains only database name
  #
  # bin/
  #
  # lib/
  #
  # libexec/
  #
  # schema/
  #   prick/
  #     prick.sql
  #     version.yml
  #
  # var/
  #   lib/
  #
  #   cache/
  #     <database>/
  #       state.yml
  #       compiler.state.yml
  #       fox.state.yml
  #
  #   log/
  #     prick.log
  #     <database>/
  #       <project>-<host>-<database>-<timestamp>.log
  #
  #   spool/
  #
  #   backup/
  #
  #   dump/
  #
  # spec/
  #
  # tmp/
  #

  # Relative paths to subdirectories
  BIN_DIRNAME = "bin"
  SCHEMA_DIRNAME = "schema"
  SCHEMA_PRICK_DIRNAME = File.join(SCHEMA_DIRNAME, "prick")
  TEST_DIRNAME = "spec"
  LIB_DIRNAME = "lib"
  LIBEXEC_DIRNAME = "libexec"
  VAR_DIRNAME = "var"
  VARLIB_DIRNAME = File.join(VAR_DIRNAME, "lib")
  LOG_DIRNAME = File.join(VAR_DIRNAME, "log")
# STATE_DIRNAME = File.join(VAR_DIRNAME, "state")
  CACHE_DIRNAME = File.join(VAR_DIRNAME, "cache")
  SPOOL_DIRNAME = File.join(VAR_DIRNAME, "spool")
  BACKUP_DIRNAME = File.join(VAR_DIRNAME, "backup")
  DUMP_DIRNAME = File.join(VAR_DIRNAME, "dump")
  TMP_DIRNAME = "tmp"

# PCK_CACHE_DIRNAME =

  # Project subdirectories ([Symbol]), used to initialize Settings#dirs. Keep
  # in sync with project *_DIRNAMES!
  PROJECT_DIR_ATTRS = [
      :bin, :schema, :schema_prick, :test, :lib, :libexec, :var, :varlib, :log,
      :cache, :spool, :backup, :dump, :tmp
  ]

  # Project filename
  PROJECT_FILENAME = "prick.yml"

  # Version filename
  VERSION_FILENAME = "version.yml"

  # Prick environment filename
  ENVIRONMENT_FILENAME = "prick.environment.yml"

  # Default reflections filename
  REFLECTIONS_FILENAME = "reflections.yml"

  # Prick state filename
  PRICK_STATE_FILENAME = ".prick.state.yml"

  # Database state file
  DATABASE_STATE_FILENAME = "state.yml"

  # Compiler state filename
  COMPILER_STATE_FILENAME = "compiler.state.yml"

  # Fox state filename
  FOX_STATE_FILENAME = "fox.state.yml"

  # Prick SQL file. Lives in the schema/prick directory and builds the prick schema
  PRICK_SQL_FILENAME = "prick.sql"

  # Suffix for prick source files
  SOURCE_EXT = "prick"

  # Default source file ('make.prick'). Also used when including directories
  # (eg. './dir' becomes './dir/make.prick')
  SOURCE_FILENAME = "make.#{SOURCE_EXT}"

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
  def self.internal(msg) = raise InternalError, msg

  def error(msg) = Prick.error msg
  def failure(msg) = Prick.failure msg
  def internal(msg) = Prick.internal msg

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

