
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
      super \
          opts, args,
          project_dir: project_dir,
          name: opts.subcommand!.name || project_dirname,
          title: opts.subcommand!.title || project_dirname.capitalize,
          prick_version: Prick::VERSION,
          version: '0.0.0'
    end

    def run
      create_dirs
      copy_files
      init_git_repo
      save_state_files
      make_git_release
    end

  private
    # Create directory structure. All directories will have a .keep file inside
    # to make git keep the directory instead of ignoring it
    def create_dirs
      for dir in Prick.settings.dirs.to_h.values
        FileUtils.mkdir_p dir
        FileUtils.touch File.join dir, ".keep"
      end
    end

    # Copy files from the prick installation share directory
    def copy_files
      DIRS.each { |rel_dstdir, rel_files|
        dstdir = File.join(Prick.settings.project_dir, rel_dstdir)
        files = rel_files.map { |file| File.join Prick.settings.prick_share_dir, file }
        FileUtils.cp_r files, dstdir
      }
      FILES.each { |rel_dstfile, rel_srcfile|
        FileUtils.cp \
            File.join(Prick.settings.prick_share_dir, rel_srcfile),
            File.join(Prick.settings.project_dir, rel_dstfile)
      }
    end

    # Create initial import commit. This commit only includes standard files
    # copied verbatim from the installation directory
    def init_git_repo
      Dir.chdir settings.project_dir do
        Bash.command %(
          git init .
          git add .
          git commit -m "Initial import"
        ), fail: true
        Bash.status == 0 or Prick.failure "Failed creating initial import"
      end
    end

    # Save project state and version
    def save_state_files
      settings.save_project
      settings.save_version
    end

    # Create first release including project files
    def make_git_release
      Dir.chdir settings.project_dir do
        Bash.command %(
          git add #{settings.project_file} #{settings.version_file}
          git commit -m "Release 0.0.0"
          git tag --message "Initial Release" v0.0.0
        ), fail: false
        Bash.status == 0 or Prick.failure "Failed creating initial release"
      end
    end

    # Map from destination directory to files in the share directory.
    # Destination directory is relative to project directory and the share
    # directory is relative to the prick installation share directory
    DIRS = {
      "schema" => %w(prick public make.prick),
      "." => %w(prick.environment.yml spec),
    }

    # Map from destination file (relative to project directory) to source file
    # (relative to the installation share directory). This is only used for
    # files that needs to be renamed (eg. dot.gitignore -> .gitignore)
    FILES = {
      ".gitignore" => "dot.gitignore"
    }
  end
end

__END__

  # FIXME: Ignores -p, -e, -s, -f options
  def self.init(project_file, dir, name, title) # dir, name, and title can be nil
    cwd = Dir.getwd
    if dir
      !File.exist?(dir) or Prick.error "Directory #{dir} exists"
      FileUtils.mkdir_p(dir)
      Dir.chdir(dir)
    else
      dir = "."
    end
    dirname = File.basename(Dir.getwd)
    name ||= dirname
    title ||= name.gsub(/[_-]/, " ").capitalize

    # Note that the initial project file is invalid and is removed again after
    # the initial commit
    Command.command %(
      git init .
      dir=#{SHARE_PATH}/init
      for path in $dir/*; do
        source_file=$(basename $path)
        dest_file=$(sed 's/^dot\././' <<<$source_file)
        cp -a $dir/$source_file $dest_file
      done
      git add .
      git commit -am "Initial import"
      rm -f #{project_file}
    ), fail: false
    Command.status == 0 or Prick.failure "Failed creating initial import"

    # Write (valid) configuration file
    state = State.new(project_file, nil, nil, nil, nil)
    settings.name = name
    settings.title = title
    settings.prick_version = PrickVersion.new VERSION
    settings.version = PrickVersion.new("0.0.0")
    settings.save_project

    # Commit configuration file and create initial release
    Command.command %(
      set -e
      git add #{project_file}
      git commit -am "Release 0.0.0"
      git tag --message "Initial Release" v0.0.0
    ), fail: false
    Command.status == 0 or Prick.failure "Failed creating initial release"

    Dir.chdir(cwd)
    [dir, name]
  end
end

