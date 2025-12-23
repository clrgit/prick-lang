
module Prick::Lang
  class CompilerProcess
    include Prick
    include ErrorFunctions

    def compiler() @compiler ||= Compiler.instance end

    forward_to :compiler, :conn, :database, :username, :environment, :verbose, :log, :dryrun

    def mode = compiler.mode
    def mode_method() @mode_method ||= "#{mode}?".to_sym end

    def parser() @parser ||= compiler.parser end
    def converter() @converter ||= compiler.converter end
    def analyzer() @analyzer ||= compiler.analyzer end
    def generator() @generator ||= compiler.generator end

    def ast() @ast ||= compiler.ast end
    def idr() @idr ||= compiler.idr end
    def units() @units ||= compiler.units end
  end

  class Compiler
    include Prick
    include ErrorFunctions
    include Prick::Lang::Timer

    DEFAULT_TARGET = "<main>"

    # Singleton instance
    def self.instance = @@INSTANCE

    # Database environment
    forward_to :settings, :database, :username, :environment

    # Owner connection
    def conn = settings.user_conn

    # Runtime options
    forward_to :settings, :dryrun?, :verbose?, :log?

    # Source and environment
    attr_reader :dir # Current user directory when the compiler was invoked
    attr_reader :file # Start file. Only used in error messages. May be nil, initialized by #parse if so
    attr_reader :mode # Symbol - Either :build or :make. Default is :build
    attr_reader :sources # [Ast::SourceFile]. List of included prick files
    attr_reader :targets # [String] - Target UIDs
    attr_reader :exclude # [String] - Excluded UIDs
    attr_reader :variables # {Var=>Val} - Command-line and built-in variables

    # Processors
    attr_reader :parser
    attr_reader :converter
    attr_reader :analyzer
    attr_reader :generator
    attr_reader :executer
    # attr_reader :dumper <- TODO

    # Data structures
    def ast = @parser.ast # Ast::Program. Initialized by #parse
    def idr = @converter.idr # Idr::Program. Initialized by #convert and updated by #analyze
    def units = @generator.units # [Unit::Node]. Initialized by #generate

    # Timestamp of last successful run
    attr_reader :timestamp # Time - time of last successful run. Default EPOCH

    # State data
    #
    # State data have default values that are overwriten by #load_compiler_state
    attr_reader :completed_resources # [uid] - Completed resource

    attr_reader :meta_tables
    attr_reader :seed_tables

    def initialize(
        file, targets = [DEFAULT_TARGET],
        mode: :build,
        timestamp: nil,
        exclude: [],
        variables: {})

      constrain file, String
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
      @file = file
      @mode = mode
      @sources = []
      @targets = targets
      @timestamp = timestamp || settings.database_state.created_at
      @exclude = exclude
      @variables = variables
      @parser = Parser.new
      @converter = Converter.new
      @analyzer = Analyzer.new
      @generator = Generator.new
      @executer = Executer.new
      @resources = {}
      @unresolved = []
      @requires = []
      @contexts = [] # Stack of [Idr::Resource, Idr::Block] tuples
      @schemas = [] # Stack of Idr::Schema objects
    end

    #
    # Compile
    #

    def compile(&block)
      t0 = Time.now
      ShellOpts.verb "Compiling '#{file}'"

      indent(verbose?) {
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

        yield

        save_compiler_state
      }

      t1 = Time.now
      ShellOpts.verb "Done (#{ftime t1 - t0})"
    end

    def interpret
      compile do
        time "Execute" do
          execute
        end
      end
    end

    #
    # Processes
    #

    # Sidenote: Here's an argument for initializing a processor object with
    # values: The main process may be broken up into subprocesses that will be
    # unable to run individually because the main process is responsible for
    # initialization. Eg. #parse needs @variables

    # Parse source file into Ast
    def parse(file = nil, lines = nil)
      Dir.chdir settings.dirs.schema do
        @file ||= file
        @parser.parse(self.file, lines)
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

    # Execute units
    def execute
      @executer.execute
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
    # if it is unknown
    def add(resource, uid = nil)
      constrain resource, Idr::Resource, Idr::ProvideCommand # FIXME Any Idr node is ok
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

    # Stack of contexts and associated block. Block is usually equal to
    # resource.block but unresolved nodes sets the resource to the parent
    # resource and the block to its own block
    attr_accessor :contexts # [[Resource, Block]]

    # Current Idr::Resource object
    def context = @contexts.last.first

    # Current Schema object
    def schema = @schemas.last

    # Current block of statements. This is usually the same as context.block
    # but unresolved nodes goes into the Unresolved object and are only later
    # moved to the parent
    def block = @contexts.last.last

    # Execute block with the given context. The current block can be set
    # explicitly, this is used by Analyze#build_unresolved
    def scope(context, block = context.block, &code)
      constrain context, Idr::Resource
      constrain block, Array
      @contexts.push [context, block]
      @schemas.push context if context.is_a? Idr::Schema
      yield
    ensure
      @contexts.pop
      @schemas.pop if context.is_a? Idr::Schema
    end

    #
    # S T A T E
    #

    # Load completed resources from compiler state file. It is not an error if
    # the file is absent
    def load_compiler_state
      @completed_resources = conn.values %(select uid from prick.resources)
      @timestamp = conn.value?("select max(created_at) from prick.builds where status = true") || EPOCH_TIMESTAMP
    end

    # Remove entries in completed_resources for the given schemas. This is
    # should be done for all schemas that are either recompiled or invalidated
    def clean_compiler_state(*schemas)
#     schemas.flatten!
#
#     conn.exec %(
#       delete from prick.resources where
    end

    # Write completed resource to compiler state file
    def save_compiler_state
      reset_compiler_state
      conn.insert "prick.resources", [:uid], @completed_resources
    end

    # Remove the compiler state if present
    def reset_compiler_state = conn.exec "delete from prick.resources"

    #
    # D U M P
    #

    def dump
      puts "Compiler"
      indent {
        puts "timestamp: #{@timestamp&.strftime("%F %T %Z") || 'nil'}"
        puts "variables"; indent { puts variables.map { |k,v| "#{k}: #{v}" } }
        puts "sources"; indent { puts sources.map(&:file) }
#       puts "files"; indent { puts sources }
        puts "resources:"
        indent {
          resources.sort_by(&:first).each { |uid, node|
            dirty = mode == :make && node.dirty? ? "*" : nil
            puts [uid, dirty, "(#{node.classname})"].compact.join(' ') + " #{node.ast.class}"
          }
        }
        puts "nodes:"
          idr.each { |node|
            puts "#{node.ast&.token || node.classname} #{node.dirty?}"
          }

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
