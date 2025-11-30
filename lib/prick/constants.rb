
__END__
module Prick
  # Paths to subdirectories relative to project directory
  BIN_DIRNAME = "bin"
  SCHEMA_DIRNAME = "schema"
  SCHEMA_PRICK_DIRNAME = File.join(SCHEMA_DIR, "prick")
  TEST_DIRNAME = "spec"
  LIB_DIRNAME = "lib"
  LIBEXEC_DIRNAME = "libexec"
  VAR_DIRNAME = "var"
  LOG_DIRNAME = File.join(VARDIR, "log")
  STATE_DIRNAME = File.join(VARDIR, "state")
  CACHE_DIRNAME = File.join(VARDIR, "cache")
  SPOOL_DIRNAME = File.join(VARDIR, "spool")
  BACKUP_DIRNAME = File.join(VARDIR, "backup")
  DUMP_DIRNAME = File.join(VARDIR, "dump")
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
  DEFAULT_DATABASE_STATE_FILE = "database.state.yml"

  # Default prick state filename
  DEFAULT_COMPILER_STATE_FILENAME = "compiler-state.yml"

  # Default fox state filename
  DEFAULT_FOX_STATE_FILENAME = "fox-state.yml"

  # Default reflections filename
  DEFAULT_REFLECTIONS_FILENAME = "reflections.yml"

  # Prick SQL file. Lives in the schema/prick directory and builds the prick schema
  PRICK_SQL_FILENAME = "prick.sql"
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


