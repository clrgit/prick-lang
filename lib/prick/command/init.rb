
module Prick::Command

  # Initialize a prick project
  class Init < BareCommand
    attr_reader :project_title
    attr_reader :project_name
    attr_reader :project_dir

    def initialize(opts, args)
      super(cmd)
      project_arg = args.expect(1)
      project_dirname = File.basename(project_arg)
      @project_dir = File.absolute_path(project_arg)
      @project_title = opts.subcommand!.title || project_dirname.capitalize
      @project_name = opts.subcommand!.name || project_dirname

      Prick.initialize(project_dir: @project_dir, state_file: opts.state_file)
    end

    def run
      create_dirs
      copy_files
      make_files
    end

  private
    def create_dirs
      FileUtils.mkdir_p Prick::PROJECT_DIRS
    end

    def copy_files
      FILES.each { |rel_dstdir, rel_files|
        dstdir = File.join(Prick::PROJECT_DIR, rel_dstdir)
        files = rel_files.map { |file| File.join Prick::PRICK_SHARE_DIR, file }
        FileUtils.cp_r files, dstdir
      }
    end

    def make_files
      Prick.save_project \
        name: project_name,
        title: project_title,
        prick_version: Prick::VERSION

      Prick.save_version \
        version: '0.0.0'
    end

    # Map from destination directory to files in prick share directory
    FILES = {
      "schema/prick" => %w(prick.sql),
#     "schema/prick" => %w(prick.sql version.yml),
    }
  end
end



