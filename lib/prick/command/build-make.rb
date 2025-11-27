
module Prick::Command
  class BuildMake < ProjectCommand
    attr_reader :compiler

    def initialize(cmd, opts, args)
      super(cmd, opts, args)

      # Extract targets
      targets = []
      while arg = args.first
        break if arg !~ /^#{Prick::Lang::Token::TARGET_PATTERN}$/
        targets << args.shift
      end
      targets = [Prick::Lang::Compiler::DEFAULT_TARGET] if targets.empty?

      #BUILTIN_VARIABLES = { cmd: "build", env: "prod", ver: Semver.new("1.2.3"), user: "me" }
#     BUILTIN_VARIABLES = { env: "prod", ver: semver.new("1.2.3"), user: "me" }

      # Extract variable assignments
#     variables.merge! BUILTIN_VERSION_VARIABLES.map { |k,v| [k.to_s, Prick.const_get(v.upcase)] }.to_h
#     variables = BUILTIN_STRING_VARIABLES.map { |k,v| [k.to_s, Prick.const_get(v.upcase)] }.to_h
#     variables.merge! BUILTIN_VERSION_VARIABLES.map { |k,v| [k.to_s, Prick.const_get(v.upcase)] }.to_h
#     variables = BUILTIN_VARIABLES.dup

      variables = BUILTIN_VARIABLES.map { |name, const| [name.to_s, Prick.const_get(const)] }.to_h
      if arg = args.shift
        case arg
          when /^(\w+)=(\S*)$/
            variables[$1.to_sym] = $2
          else
            ShellOpts::error "Illegal argument '#{arg}'"
        end
      end

      # Create compiler object
      @compiler = Prick::Lang::Compiler.new(
          file, targets,
          mode: cmd.to_sym,
          state_file: opts.state_file,
          timestamp: opts.timestamp && Time.parse(opts.timestamp),
          exclude: opts.exclude?,
          dryrun: opts.dryrun?,
          variables: variables,
          log: log)
    end


    def run
      puts "RUNNING"
      return
      begin
        compiler.interpret
        super
      rescue => ex
        raise Prick::Lang::ErrorFunctions.pretty_backtrace!(ex)
      end
    end

    BUILTIN_VARIABLES = {
      database: :PRICK_DATABASE,
      username: :PRICK_USERNAME,
      environment: :PRICK_ENVIRONMENT,
      version: :PROJECT_VERSION,
      prick_version: :PRICK_VERSION
    }

#   BUILTIN_VARIABLES = [:database, :username, :environment, :version, :prick_version]
#   BUILTIN_STRING_VARIABLES = [:database, :username, :environment]
#   BUILTIN_VERSION_VARIABLES = [:version, :prick_version]


#   # Handle dump option. 'units' is the default
#   if opts.dump?
#     kinds = opts.dump || "units"
#     (unknowns = kinds - Prick::Lang::DUMP_KINDS) or
#         ShellOpts::error "Illegal value for --dump '#{unknowns.first}'"
#     Prick::Lang.dump(compiler, kinds)
#     exit
#   end
  end
end


__END__

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

      # Handle dump option. 'units' is the default
      if opts.dump?
        kinds = opts.dump || "units"
        (unknowns = kinds - Prick::Lang::DUMP_KINDS) or ShellOpts::error "Illegal value for --dump '#{unknowns.first}'"
        Prick::Lang.dump(compiler, kinds)
        exit
      end

