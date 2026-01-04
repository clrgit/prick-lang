
module Prick::Lang
  class CompilerProcess
    include Prick
    include ErrorFunctions

    def compiler() @compiler ||= Compiler.instance end
    def executer() @executer ||= Executer.instance end

    forward_to :compiler, :conn, :database, :username, :environment, :schemas, :verbose, :log, :dryrun

    def mode = compiler.mode
    def mode_method() @mode_method ||= "#{mode}?".to_sym end

    def parser() @parser ||= compiler.parser end
    def converter() @converter ||= compiler.converter end
    def analyzer() @analyzer ||= compiler.analyzer end
    def generator() @generator ||= compiler.generator end

    # Why not forward_to?
    def ast() @ast ||= compiler.ast end
    def idr() @idr ||= compiler.idr end
    def units() @units ||= compiler.units end
    def program() = compiler.program
  end

  class Compiler
    include Prick
    include ErrorFunctions
    include Prick::Lang::Timer

    DEFAULT_TARGET = "<main>"

    # Singleton instance
    def self.instance = @@INSTANCE

    # Absolute path to main source file (after -C). Note that
    # #settings.source_file is not necessarily an absolute path
    attr_reader :source_file

    # Database environment
    forward_to :settings, :database, :username, :environment

    # Owner connection
    def conn = settings.user_conn

    # Runtime options
    forward_to :settings, :dryrun?, :verbose?, :log?

    # Source and environment
#   attr_reader :file # Source file relative to the current directory (after -C)
    attr_reader :dir # Current user directory when the compiler was invoked (before -C)
    attr_reader :mode # Symbol - Either :build or :make. Default is :build
    attr_reader :sources # { String => Ast::SourceFile }. Hash of included prick files
    attr_reader :targets # [String] - Target UIDs
    attr_reader :exclude # [String] - Excluded UIDs
    attr_reader :variables # {Var=>Val} - Command-line and built-in variables

    # Processors
    attr_reader :parser
    attr_reader :converter
    attr_reader :analyzer
    attr_reader :generator
    # attr_reader :dumper <- TODO

    # Data structures
    def ast = @parser.ast # Ast::Program. Initialized by #parse
    def idr = @converter.idr # Idr::Program. Initialized by #convert and updated by #analyze
    def units = @generator.execute_units # [Unit::Node]. Units to execute. Initialized by #generate

    # Top-level Idr Program node. Just a synonym for #idr. Intialized by the analyzer
    alias_method :program, :idr

    # Idr schemas. This excludes Ast schemas that was filtered away by the
    # converter process. These schemas may be ignored later in the compile
    # process, though
    attr_reader :schemas # { String => Idr::Schema }, initialized by the analyzer

    # State data. State data are read by #load_compiler_state

    # Timestamp of last run, default EPOCH. The timestamp for the current run
    # (successful or nor) can be found as settings.created_at
    #
    # TODO: Register last successful run per file (maybe... PRICK.RESOURCES
    # implicitly reflects this state)
    attr_reader :timestamp # Time

    # Completed resources from PRICK.RESOURCES. This is always the resources
    # from the last run when prick was started. New completed resources are
    # registered directly in database when the script is executed
    attr_reader :completed_resources # [uid]

    # Lists of meta and seed tables
    attr_reader :meta_tables
    attr_reader :seed_tables

    # Affected schemas
    attr_reader :affected_schemas

    def initialize(
        targets = [DEFAULT_TARGET],
        mode: :build,
        timestamp: nil,
        exclude: [],
        variables: {})

      constrain targets, [String]
      constrain mode, :build, :make
      constrain timestamp, Time, nil
      constrain exclude, [String]
      constrain variables.keys, [Symbol]
      constrain variables.values, [String, Semver, nil]

#     @@INSTANCE.nil? or raise ArgumentError, "Compiler is a singleton" # Interferes with testing
      @@INSTANCE = self
      @dir = Dir.getwd
      @dir_pathname = Pathname.new(@dir) # pre-computed, used in #userpath
      @source_file = File.absolute_path(settings.source_file)
      @mode = mode
      @sources = {}
      @targets = targets
#     exit if !timestamp.nil?
      @timestamp = timestamp || settings.database_state.created_at
      @exclude = exclude
      @variables = variables
      @parser = Parser.new
      @converter = Converter.new
      @analyzer = Analyzer.new
      @generator = Generator.new
      @schemas = {}
      @resources = {}
      @unresolved = []
      @requires = []
      @context_stack = [] # Stack of [Idr::Resource, Idr::Block] tuples
      @schema_stack = [] # Stack of Idr::Schema objects
    end

    #
    # Processes
    #

    # Sidenote: Here's an argument for initializing a processor object with
    # values: The main process may be broken up into subprocesses that will be
    # unable to run individually because the main process is responsible for
    # initialization. Eg. #parse needs @variables

    # Parse source into Ast. The source can be a file name and/or an array of
    # lines. The file is not read if lines is defined
    def parse(lines = nil)
#     dir = File.dirname(settings.source_file)
#     file = File.basename(settings.source_file)
      Dir.chdir dir do
#       @parser.parse(file, lines)
        @parser.parse(lines)
      end
    end

    # Convert Ast to Idr
    def convert
      @converter.convert
    end

    # Analyze Idr
    def analyze(link: nil)
      @analyzer.analyze(link: link)
    end

    # Generate units
    def generate
      @generator.generate
    end

    #
    # Runtime variables
    #

    # Hash of variables
    attr_reader :variables # Symbol => String
    forward_to :@variables, :[], :[]=, :key?

    #
    # Resources
    #
    # A resource is a phase, function, schema, or program object, or a provide
    # statement

    # Map from uid to Idr resource object, false if marked absent and nil if
    # unknown
    attr_reader :resources # UID String => Idr::Node/false/nil

    # Add an unknown resource if not present. Return the uid
    def ensure(value)
      constrain value, Ast::Value
      uid = self.uid(value.value)
      @resources[uid] = nil if !@resources.key?(uid)
      uid
    end

    # Add a present resource. It is an error if the resource is absent but not
    # if it is unknown. It the resource is a schema, it is also added FIXME ...to what?
    def add(resource, uid = nil)
      constrain resource, Idr::ResourceUID # [Resource, ProvideCommand] FIXME Any Idr node is ok
      uid ||= resource.uid
      if !@resources[uid].nil?
        if @resources[uid]
          error resource.token, "Redefinition of '#{uid}'"
        else
          error resource.token, "'#{uid}' has been marked absent"
        end
      end
      @resources[uid] = resource
    end

    #
    # Presense
    #

    # Unresolved nodes
    attr_accessor :unresolved # [Unresolved]

    # Lists of present, absent, known, or unknown resource UIDs
    def present = @resources.filter_map { _2 and _1 }
    def absent = @resources.filter_map { ! _2.nil? && ! _2 and _1 }
    def known = @resources.filter_map { !_2.nil? and _1 }
    def unknown = @resources.filter_map { _2.nil? and _1 }

    # True if the resource is present
    def present?(uid) = (entry(uid) && true || false)

    # True if the resource is absent
    def absent?(uid) = (entry(uid) || false) && true

    # True if the resource is either present or absent
    def known?(uid) = !entry(uid).nil?

    # True if it is not known if the resource is present or absent
    def unknown?(uid) = entry(uid).nil?

    # Mark all unknown nodes as absent
    def mark_unknown_absent = unknown.each { |key| @resources[key] = false }

    #
    # Contexts
    #

    # Stack of context_stack and associated block. Block is usually equal to
    # resource.block but unresolved nodes sets the resource to the parent
    # resource and the block to its own block
    attr_accessor :context_stack # [[Resource, Block]]

    # Current Idr::Resource object
    def context = @context_stack.last.first

    # Current Schema object
    def schema = @schema_stack.last

    # Current block of statements. This is usually the same as context.block
    # but unresolved nodes goes into the Unresolved object and are only later
    # moved to the parent
    def block = @context_stack.last.last

    # Execute block with the given context. The current block can be set
    # explicitly, this is used by Analyze#build_unresolved
    def scope(context, block = context.block, &code)
      constrain context, Idr::Resource
      constrain block, Array
      @context_stack.push [context, block]
      @schema_stack.push context if context.is_a? Idr::Schema
      yield
    ensure
      @context_stack.pop
      @schema_stack.pop if context.is_a? Idr::Schema
    end

    #
    # Compile
    #

    def compile
      begin
        t0 = Time.now

        reset_compiler_state if mode == :build
        load_compiler_state

        time "Parsing" do
          parse
        end

        time "Converting" do
          convert
        end

        time "Analyzing" do
          analyze
        end

        time "Generating" do
          generate
        end

        dt = Time.now - t0
        settings.compile_duration = dt

        save_compiler_state

      rescue
        @parser&.tokenizer&.dump
        raise
      end
    end

#   def interpret
#     raise
#     compile do
#       t0 = Time.now
#       time "Executing" do
#         execute
#       end
#       t1 = Time.now
#       dt = t1 - t0
#       settings.execute_duration = dt
#     end
#   end

    #
    # S T A T E
    #

    # Load completed resources from PRICK.RESOURCES and the last successful
    # timestamp (TODO: needs much more work). Note that there is no
    # corresponding #save_compiler_state because resources are created as the
    # program is executed
    def load_compiler_state
      @completed_resources = conn.values %(select uid from prick.resources)
    end

    def save_compiler_state
      # Add meta tables etc.
    end

    # Remove the compiler state. This is used by 'prick build'
    def reset_compiler_state
      conn.exec "delete from prick.resources"
    end

    #
    # Utilities
    #

    # Compute fully qualified uid - prepends the current context uid to the
    # ident if absent
    def uid(ident)
      constrain ident, String
      (ident.index('.') ? ident : [context.uid, ident].compact.join("."))
    end
    def self.uid(ident) = instance.uid(ident)

    # Compute path relative to #dir, this is used in error messages
    def userpath(path)
      Pathname.new(File.expand_path(path)).relative_path_from(@dir_pathname).to_s
    end
    def self.userpath(path) = instance.userpath(path)

    #
    # D U M P
    #

    # Shorten error messages
    def inspect = "#<Compiler ...>"

    def dump
      puts "Compiler"
      indent {
        puts "timestamp: #{@timestamp&.strftime("%F %T %Z") || 'nil'}"
        puts "created_at: #{settings.created_at.strftime("%F %T %Z")}"
        pindent "variables:" do puts variables.map { |k,v| "#{k}: #{v}" } end
        pindent "sources:" do puts sources.keys end
        pindent "resources ('*' - dirty):" do
          resources.sort_by(&:first).each { |uid, node|
            dirty = mode == :make && node.dirty? ? "*" : nil
            puts [uid, dirty, "(#{node.classname})"].compact.join(' ') + " #{node.ast.class}"
          }
        end

        pindent "nodes:" do
          kinds = [:dirty, :built, :excluded, :build, :make]
          methods = kinds.map { |k| [k, :"#{k}?"] }.to_h
          counts = kinds.map { |k| [k, 0] }.to_h
          idr.each { |node|
            for kind, method in methods
              counts[kind] += 1 if node.send(method)
            end
          }
          puts "all: #{counts.values.sum}"
          for kind in kinds
            puts "#{kind}: #{counts[kind]}"
          end
        end

#       indent {
#         puts "present:"; indent { puts present.map { "#{_1} (#{@resources[_1].classname})" } }
#         puts "absent:"; indent { puts absent }
#         puts "unknown:"; indent { puts unknown }
#       }
#       if unresolved.empty?
#         puts "unresolved: []"
#       else
#         puts "unresolved (#{unresolved.size}):"
#         indent {
#           unresolved.each { |node| puts "#{node.token.location}: #{node.unresolved_uid} #{node.classname}" }
#         }
#       end
      }
    end

    def dump_units
      units.each { |unit| puts "TODO" }
    end

  private
    @@INSTANCE = nil

    def entry(uid)
      constrain uid, String
      @resources.key?(uid) ? @resources[uid] : (@resources[uid] = nil)
    end
  end
end
