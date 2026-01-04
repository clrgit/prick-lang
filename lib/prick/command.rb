
module Prick::Command
  # Common class for prick command implementations
  class Command
    include Prick
    include Prick::Lang::Timer

    # The name of the command. 'init', 'build', 'list', ...
    attr_reader :cmd # String

    # Options for the command
    attr_reader :opts

    # Arguments
    attr_reader :args

    # Map from setting member to value. These values are written to the setting
    # object when the command is initialized
    attr_reader :attrs

    def initialize(opts, args, project_dir: nil, **attrs, &block)
      @cmd = self.class.to_s.sub(/^.*::/, "").downcase
      @opts, @args, @attrs = opts, args, attrs

      # Initialize prick and set options
      Prick.initialize(
        project_dir: project_dir,
        **attrs.merge({
          database: opts.database,
          superuser: opts.superuser || ENV['USER'],
          source_file: opts.file || Prick::SOURCE_FILE,
          reflections_file: opts.reflections_file,
          verbose: opts.verbose?,
          dryrun: opts.dryrun?,
          log: opts.log?
        }.select { |k,v| !v.nil? })
      )
    end

    # Run the command. Should be defined in derived classes
    def run() = raise
  end

  def self.create(cmd, opts, args)
    klass =
        case cmd
          when "init"; Prick::Command::Init
          when "setup"; Prick::Command::Setup
          when "teardown"; Prick::Command::Teardown
          when "info"; Prick::Command::Info
          when "list"; Prick::Command::List
          when "cd"; Prick::Command::CD
          when "pwd"; Prick::Command::PWD
          when "build"; Prick::Command::Build
          when "make"; Prick::Command::Make
        else
          ShellOpts.failure "'#{cmd}' command is not implemented yet"
        end
    klass.new(opts, args)
  end
end

require_relative './command/init.rb'
require_relative './command/setup.rb'
require_relative './command/teardown.rb'
require_relative './command/info.rb'
require_relative './command/list.rb'
require_relative './command/cd.rb'
require_relative './command/pwd.rb'
require_relative './command/build-make.rb'


