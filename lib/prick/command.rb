
module Prick::Command
  # Common class for prick command implementations
  class Command
    include Prick

    # The name of the command. 'init', 'build', 'list', ...
    attr_reader :cmd

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


__END__
  class BuildCommand < Command
    def initialize
  end


  def make_compiler(opts, args)
    Prick.initialize(state_file: state_file, new: false)

    # Extract targets
    targets = []
    while arg = args.first
      break if arg !~ /^#{Prick::Lang::Token::TARGET_PATTERN}$/
      targets << args.shift
    end
    targets = [Prick::Lang::Compiler::DEFAULT_TARGET] if targets.empty?

    # TODO: Load prick.yml

    # FIXME
    #BUILTIN_VARIABLES = { cmd: "build", env: "prod", ver: Semver.new("1.2.3"), user: "me" }
    BUILTIN_VARIABLES = { env: "prod", ver: Semver.new("1.2.3"), user: "me" }

    # Extract variable assignments
    variables = BUILTIN_VARIABLES.dup
    if arg = args.shift
      case arg
        when /^(\w+)=(\S*)$/
          variables[$1.to_sym] = $2
        else
          ShellOpts::error "Illegal argument '#{arg}'"
      end
    end

    # Create compiler object
    compiler = Prick::Lang::Compiler.new(
        file, targets,
        mode: cmd.to_sym,
        state_file: state_file,
        timestamp: timestamp,
        exclude: exclude,
        variables: variables,
        dryrun: dryrun,
        log: log)

    # Handle dump option. 'units' is the default
    if opts.dump?
      kinds = opts.dump || "units"
      (unknowns = kinds - Prick::Lang::DUMP_KINDS) or ShellOpts::error "Illegal value for --dump '#{unknowns.first}'"
      Prick::Lang.dump(compiler, kinds)
      exit
    end

  end

  def create(cmd, opts, args)
      case cmd
        when "init"
          Command.init(project_name)

        when "build", "make"
          Prick.initialize(state_file: state_file, new: false)

          # Extract targets
          targets = []
          while arg = args.first
            break if arg !~ /^#{Prick::Lang::Token::TARGET_PATTERN}$/
            targets << args.shift
          end
          targets = [Prick::Lang::Compiler::DEFAULT_TARGET] if targets.empty?

          # TODO: Load prick.yml

          # FIXME
          #BUILTIN_VARIABLES = { cmd: "build", env: "prod", ver: Semver.new("1.2.3"), user: "me" }
          BUILTIN_VARIABLES = { env: "prod", ver: Semver.new("1.2.3"), user: "me" }

          # Extract variable assignments
          variables = BUILTIN_VARIABLES.dup
          if arg = args.shift
            case arg
              when /^(\w+)=(\S*)$/
                variables[$1.to_sym] = $2
              else
                ShellOpts::error "Illegal argument '#{arg}'"
            end
          end

          # Create compiler object
          compiler = Prick::Lang::Compiler.new(
              file, targets,
              mode: cmd.to_sym,
              state_file: state_file,
              timestamp: timestamp,
              exclude: exclude,
              variables: variables,
              dryrun: dryrun,
              log: log)

          # Handle dump option. 'units' is the default
          if opts.dump?
            kinds = opts.dump || "units"
            (unknowns = kinds - Prick::Lang::DUMP_KINDS) or ShellOpts::error "Illegal value for --dump '#{unknowns.first}'"
            Prick::Lang.dump(compiler, kinds)
            exit
          end

          # Compile
          begin
            compiler.interpret
          rescue => ex
            raise Prick::Lang::ErrorFunctions.pretty_backtrace!(ex)
          end

  end

  class Command
    attr_reader :cmd, :opts, :args
    def initialize(cmd, opts, args) @cmd, @opts, @args = cmd, opts, args end

    def exec

      else
        raise
      end
    end
  end

  def init
  end

  # Implements the 'prick init' command
  def self.init(project_name)
    Init.new(project_name).init
  end

  def self.build
  end

  def self.make
  end

  def self.command(sym, *args) = self.send sym, *args
end
