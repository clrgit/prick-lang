
module Prick::Command
  # Common code for Build and Make classes. They differ only in the #cmd value
  class BuildMake < Command
    # Supported dump kinds
    DUMP_KINDS = %w(
        tokens ast idr analyzer source files nodes resources
        schemas deps reqs refs generator units state)

    BUILTIN_VARIABLES = [:database, :username, :environment, :version, :prick_version ]

    attr_reader :compiler
    attr_reader :executer

    attr_reader :dump_kinds

# --timestamp=TIMESTAMP
#   Override timestamp from the compiler state file

    def initialize(opts, args)
      super opts, args

      # Get dump opts. nil if not present
      @dump_kinds = opts.dump

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
    end

    def run
      return dump(dump_kinds) if dump_kinds
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

    def dump(kinds)
      # Check kinds and assign default
      kinds = opts.dump || "units"
      (unknowns = kinds - DUMP_KINDS) or
          ShellOpts::error "Illegal value for --dump '#{unknowns.first}'"

      # Explicitly load database state. This is usually done in
      # Compiler#compile
      compiler.load_compiler_state

      # Tokens are captured as they are read by the tokenizer (and ultimately the
      # parser). They don't have a data structure of their own so instead we
      # install a listener to register them as they are created
      tokens = []
      install_token_listener(tokens) if kinds.include? "tokens"

      # Tokens and ast
      compiler.parse
      dump_tokens(tokens) if kinds.delete "tokens"
      compiler.ast.dump if kinds.delete "ast"
      return if kinds.empty?

      # Converter. FIXME Explain strange result if run before analyzer
      compiler.convert

      # Analyzer
      compiler.analyzer.analyze
      compiler.idr.dump if kinds.delete "idr" # FIXME Should be moved before #analyze

      compiler.analyzer.dump if kinds.delete "analyzer"
      compiler.analyzer.dumpsource if kinds.delete "source"
      compiler.analyzer.dumpfiles if kinds.delete "files"
      compiler.analyzer.dumpnodes if kinds.delete "nodes"
      compiler.analyzer.dumpresources if kinds.delete "resources"
      compiler.analyzer.dumpschemas if kinds.delete "schemas"

      compiler.dumpdeps if kinds.delete "deps"
      compiler.dumpreqs if kinds.delete "reqs"
      compiler.dumprefs if kinds.delete "refs"
      return if kinds.empty?

      # Generator
      compiler.generate
      compiler.generator.dump if kinds.delete "generator"
      puts compiler.units.map(&:to_s) if kinds.delete "units"

      # Compiler
      compiler.dump if kinds.delete "state"

      # Should never happen but safe guards against developer errors
      kinds.empty? or ShellOpts.error "Illegal dump option '#{kinds.first}'"
    end
  end

  def dump_tokens(tokens)
    puts "Tokens"
    indent { puts tokens.map(&:to_s) }
  end

  # Used to dump tokens as they are processed. The problem is that the kind of
  # a token depends on the context so we need to run the parser to get the
  # right interpretation
  def install_token_listener(tokens)
    Token.alias_method(:orig_initialize, :initialize)
    Token.define_method(:initialize) { |*args| orig_initialize(*args); tokens << self; }
  end

  class Build < BuildMake
  end

  class Make < BuildMake
  end

  class Merge < BuildMake
  end
end

