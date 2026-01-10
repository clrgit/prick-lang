
module Prick::Command
  # Common code for Build and Make classes. They differ only in the #cmd value
  class BuildMake < Command
    BUILTIN_VARIABLES = [:database, :username, :environment, :version, :prick_version ]

    attr_reader :compiler
    attr_reader :executer

# --timestamp=TIMESTAMP
#   Override timestamp from the compiler state file

    def initialize(opts, args)
      super opts, args

      # Define builtin variables and extract additional variables from command line
      variables = BUILTIN_VARIABLES.map { |attr| [attr, settings.send(attr)] }.to_h
      while arg = args.first and arg =~ /^(\w+)=(\S*)$/
        variables[$1.to_sym] = $2
        args.shift
      end

      # Extract targets
      targets = []
      while arg = args.first
        arg =~ /^#{Prick::Lang::Token::TARGET_PATTERN}$/ or ShellOpts::error "Illegal argument '#{arg}'"
        targets << args.shift
      end

      # Handle merge command and set default target
      if cmd == "merge"
        targets.each { |target| target =~ /\.MERGE$/ or ShellOpts::error "Not a merge target '#{target}'" }
        default = Prick::Lang::Compiler::DEFAULT_MERGE_TARGET
      else
        targets.each  { |target| target !~ /\.MERGE$/ or ShellOpts::error "Can't build merge target '#{target}'" }
        default = Prick::Lang::Compiler::DEFAULT_TARGET
      end
      targets = [default] if targets.empty?

      # Create compiler object
      @compiler = Prick::Lang::Compiler.new(
          targets,
          mode: cmd.to_sym,
          timestamp: opts.timestamp && Time.parse(opts.timestamp),
          exclude: opts.exclude,
          variables: variables
      )

      # Executer object
      @executer = Prick::Lang::Executer.new

      # Handle dump option. 'units' is the default
      if opts.dump?
        kinds = opts.dump || "units"
        (unknowns = kinds - Prick::Lang::DUMP_KINDS) or
            ShellOpts.error "Illegal value for --dump '#{unknowns.first}'"
        Prick::Lang.dump(compiler, kinds)
        exit
      end
    end

    def run
      begin
        t0 = Time.now
        ShellOpts.verb "Building #{settings.database} #{settings.source_file}"
        indent {
          compiler.compile
          executer.execute
        }
        dt = Time.now - t0
        ShellOpts.verb "Done (#{ftime dt})"
      rescue => ex
        raise Prick::Lang::ErrorFunctions.pretty_backtrace!(ex)
      end
    end

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

  class Build < BuildMake
  end

  class Make < BuildMake
  end

  class Merge < BuildMake
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

