
require 'shellopts' # Because it must be required before this file

module Prick
  def self.initialize_constants(project_dir = nil)
    # Prick gem installation directory. Used to find the share directoryto find
    # the share directoryby files. Note that constants.rb should be required
    # before any directory changes
    PRICK_DIR = File.dirname ShellOpts.path

    # Installation share directory
    PRICK_SHARE_DIR = "#{PRICK_DIR}/lib/prick/share"

    # Absolute path to the directory of the user process that invoked prick.
    # Prick changes directory while running the code so error messages has to be
    # modified relative to the environment of the user to make sense
    ENVIRONMENT_DIR = Dir.getwd

    # Project filename
    PROJECT_FILENAME = "prick.yml"

    # Full path to project root directory. nil when running rspec
    PROJECT_DIR = project_dir || begin
      dir = Dir.getwd
      while dir != "/" && !File.exist?("#{dir}/#{PROJECT_FILENAME}")
        dir = File.dirname(dir)
      end
      if dir == "/" # RSpec compatibility
        defined?(RSpec) or ShellOpts.error "Can't find prick project directory"
        dir = ""
      end
      dir
    end

    # Full path to the prick project file
    PROJECT_FILE = File.join(PROJECT_DIR, PROJECT_FILENAME)

    # Full path to project directories
    PROJECT_DIRS = [
      BIN_DIR = File.join(PROJECT_DIR, "bin"),
      SCHEMA_DIR = File.join(PROJECT_DIR, "schema"),
      SCHEMA_PRICK_DIR = File.join(SCHEMA_DIR, "prick"),
      TEST_DIR = File.join(PROJECT_DIR, "spec"),
      LIB_DIR = File.join(PROJECT_DIR, "lib"),
      LIBEXEC_DIR = File.join(PROJECT_DIR, "libexec"),
      VAR_DIR = File.join(PROJECT_DIR, "var"),
      LOG_DIR = File.join(VARDIR, "/log"),
      STATE_DIR = File.join(VARDIR, "/state"),
      CACHE_DIR = File.join(VARDIR, "/cache"),
      SPOOL_DIR = File.join(VARDIR, "/spool"),
      BACKUP_DIR = File.join(VARDIR, "/backup"),
      DUMP_DIR = File.join(VARDIR, "/dump")
    ]

    # Default prick state file
    PRICK_STATE_FILE = "#{STATE_DIR}/prick.state.yml"
  end
end

__END__

module Prick
  ### TIME

  EPOCH = Time.at(0).utc

  ### DIRECTORIES AND FILE NAMES

  # Shared files (part of the installation)
  SHARE_PATH = "#{File.dirname(File.dirname(__dir__))}/lib/prick/share"
  LIBEXEC_PATH = "#{File.dirname(File.dirname(__dir__))}/lib/prick/libexec"

  # Project directories (relative to PROJECT_DIR)
  DIRS = [
    MIGRATION_DIR = "migration",
    SCHEMA_DIR = "schema",
    SCHEMA_PRICK_DIR = "#{SCHEMA_DIR}/prick",
    PUBLIC_DIR = "#{SCHEMA_DIR}/public",
    BIN_DIR = "bin",
    LIBEXEC_DIR = "libexec",
    VAR_DIR = "var",
    CACHE_DIR = "#{VAR_DIR}/cache",
    SPOOL_DIR = "#{VAR_DIR}/spool",
    TMP_DIR = "tmp",
    CLONE_DIR = "tmp/clones",
    SPEC_DIR = "spec"
  ]

  # Search path for executables
  PRICK_PATH = "#{PROJECT_DIR}/#{BIN_DIR}:#{ENV['PATH']}"

  # Project file path
  PRICK_PROJECT_FILE = File.join(PROJECT_DIR, PRICK_PROJECT_FILE)

  # Environment file
  PRICK_ENVIRONMENT_FILE = "prick.environment.yml"
  PRICK_ENVIRONMENT_PATH = File.join(PROJECT_DIR, PRICK_ENVIRONMENT_FILE)


  # TODO: Move to var/cache

  # State file
  PRICK_STATE_FILE = ".prick.state.yml"
  PRICK_STATE_PATH = File.join(PROJECT_DIR, PRICK_STATE_FILE)

  # Fox state file (contains anchors and table sizes)
  FOX_STATE_FILE = ".fox-state.yml"
  FOX_STATE_PATH = File.join(PROJECT_DIR, FOX_STATE_FILE)

  # PgMeta snapshot. Is deleted at the start of each build
  PG_META_STATE_FILE = ".pg_meta-state.yml"
  PG_META_STATE_PATH = File.join(PROJECT_DIR, PG_META_STATE_FILE)

  # Reflections file
  REFLECTIONS_FILE = "reflections.yml"
  REFLECTIONS_PATH = File.join(SCHEMA_DIR, REFLECTIONS_FILE)

  # Schema data file
  SCHEMA_VERSION_FILE = "data.sql"
  SCHEMA_VERSION_PATH = File.join(SCHEMA_PRICK_DIR, SCHEMA_VERSION_FILE)

  # Rspec temporary directory
  SPEC_TMP_DIR = "spec"
  SPEC_TMP_PATH = File.join(TMP_DIR, SPEC_TMP_DIR)

  # Migration diff files
  DIFF_FILE = "diff.sql"
  DIFF_FILES = [
    BEFORE_TABLES_DIFF_FILE = "diff.before-tables.sql",
    TABLES_DIFF_FILE = "diff.tables.sql",
    AFTER_TABLES_DIFF_FILE = "diff.after-tables.sql"
  ]

  # Default environment
  DEFAULT_ENVIRONMENT = "default"


