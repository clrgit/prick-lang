
module Prick::Lang

  # Initialize a prick project
  class Initializer
    attr_reader :project

    def initialize(project)
      @project = project
    end

    def init
      check_database

      create_dirs
      copy_files
      init_files

      init_database
    end

    def check_database # TODO: PRICK_DATABASE/PRICK_USERNAME
    end

    def create_dirs
      FileUtils.mkdir_p PROJECT_DIRS
    end

    def copy_files
      FILES.each { |dstdir, files|
        FileUtils.cp_r files.map { |file| File.join PRICK_SHARE_DIR, file }, dstdir
      }
    end

    # FIXME versions are specified both here and in schema/prick/
    def init_files
      data = {
        name: project,
        version: '0.0.0',
        prick_version: '0.0.0'
      }
      IO.write PROJECT_FILE, data.to_yaml
    end

    def init_database
      # Create user
      # Create database
      # Build prick schema
    end

    # Map from destination directory to files in prick share directory
    FILES = {
      "schema/prick" => %w(prick.sql version.yml),
    }
  end
end



