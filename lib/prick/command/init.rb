
module Prick::Command

  # Initialize a prick project
  class Init < Command
    # --name=NAME --title=TITLE -- [DIR]
    def initialize(opts, args)
      project_arg = args.expect(0..1) || Dir.getwd
      project_dirname = File.basename(project_arg)
      project_dir = File.absolute_path(project_arg)

      # Create directory if needed
      FileUtils.mkdir_p project_dir

      # Check for existing project
      !File.exist? File.join(project_dir, Prick::PROJECT_FILENAME) or
          ShellOpts.error "Won't overwrite existing project"

      # Initialize Prick
      super(
        "init", opts, args,
        project_dir: project_dir,
        name: opts.subcommand!.name || project_dirname,
        title: opts.subcommand!.title || project_dirname.capitalize,
        prick_version: Prick::VERSION,
        version: '0.0.0',
        load_files: [],
        save_files: [:project_file]
      )
    end

    def run
      create_dirs
      copy_files
      save_state_files
      init_git_repo
    end

  private
    def create_dirs
      FileUtils.mkdir_p Prick.state.project_dirs
    end

    def copy_files
      DIRS.each { |rel_dstdir, rel_files|
        dstdir = File.join(Prick.state.project_dir, rel_dstdir)
        files = rel_files.map { |file| File.join Prick.state.prick_share_dir, file }
        FileUtils.cp_r files, dstdir
      }
      FILES.each { |rel_dstfile, rel_srcfile|
        FileUtils.cp \
            File.join(Prick.state.prick_share_dir, rel_srcfile), 
            File.join(Prick.state.project_dir, rel_dstfile)
      }
    end

    def save_state_files
      state.save_project
      state.save_version
    end

    def init_git_repo
      # TODO
    end

    # Map from destination directory to files in the share directory.
    # Destination directory is relative to project directory and the share
    # directory is relative to the prick installation share directory
    DIRS = {
      "schema" => %w(prick public make.prick),
      "." => %w(prick.environment.yml spec),
    }

    # Map from destination file relative to project directory to source file
    # relative to installation share directory. This is used for files that needs
    # to be renamed
    FILES = {
      ".gitignore" => "dot.gitignore"
    }
  end
end



