
module Prick::Lang
  class CompilerProcess
    include ErrorFunctions
    def compiler() @compiler ||= Compiler.instance end
    def parser() @parser ||= compiler.parser end
    def converter() @converter ||= compiler.converter end
    def analyzer() @analyzer ||= compiler.analyzer end
    def generator() @generator ||= compiler.generator end

    def ast() @ast ||= compiler.ast end
    def idr() @idr ||= compiler.idr end
    def units() @units ||= compiler.units end
  end

  class Compiler
    include ErrorFunctions

    DEFAULT_TARGET = "<main>"

    # File or completed resources. Used by 'prick make'
    COMPLETED_RESOURCES_FILE = ".prick-resources"

    # Source and environment
    attr_reader :dir # Current user directory when the compiler was invoked
    attr_reader :file # Start file. Only used in error messages. May be nil, initialized by #parse if so
    attr_reader :targets # [String] - Target UIDs
    attr_reader :exclude # [String] - Excluded UIDs
    attr_reader :variables # {Var=>Val} - Command-line and built-in variables

    # Processors
    attr_reader :parser
    attr_reader :converter
    attr_reader :analyzer
    attr_reader :generator

    # Data structures
    def ast = @parser.ast # Ast::Program. Initialized by #parse
    def idr = @converter.idr # Idr::Program. Initialized by #convert and updated by #analyze
    def units = @generator.units # [Unit::Node]. Initialized by #generate

    # Meta data
    attr_reader :completed_resources # [uid] - Completed resource
    attr_reader :completed_resources_file # String - Completed resource file

    def initialize(file, targets = [DEFAULT_TARGET], resource_file: nil, exclude: [], variables: {})
      constrain file, String
      constrain targets, [String]
      constrain exclude, [String]
      constrain variables, { Symbol => [String, Semver] }
#     @@INSTANCE.nil? or raise ArgumentError, "Compiler is a singleton" # Interferes with testing
      @@INSTANCE = self
      @dir = Dir.getwd
      @dir_pathname = Pathname.new(@dir) # pre-computed, used in #userpath
      @file = file
      @targets = targets
      @exclude = exclude
      @variables = variables
      @completed_resources_file = completed_resources_file || COMPLETED_RESOURCES_FILE
#     @completed_resources = load_completed_resources
      @completed_resources = []
      @parser = Parser.new
      @converter = Converter.new
      @analyzer = Analyzer.new
      @generator = Generator.new
      @resources = {}
      @unresolved = []
      @requires = []
      @contexts = []
    end

    # Load and store completed resources
    def load_completed_resources
      File.exist?(completed_resources_file) ? IO.readlines(completed_resources_file).map(&:chomp) : []
    end
    def save_compleated_resources(resources) = File.open(completed_resources_file, "w") { _1.puts resources }

    # Singleton instance
    def self.instance = @@INSTANCE

    #
    # General methods
    #

    # Sidenote: Here's an argument for initializing a processor object with
    # values: The main process may be broken up into subprocesses that will be
    # unable to run individually because the main process is responsible for
    # initialization. Eg. #parse needs @variables

    def parse(file = nil, lines = nil)
      @file ||= file
      @parser.parse(file, lines)
    end

    def convert
      @converter.convert
    end

    def analyze
      @analyzer.analyze
    end

    def generate
      @generator.generate
    end

    def compile
      time "Parsing #{file}" do
        parse(file, lines)
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

#     puts "Dumping"
#     program.dump
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
    # A resource is a phase, function, schema, or program Idr object or a
    # provide statement

    # Map from uid to Idr resource object, false if marked absent,
    # and nil if unknown
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
    # resource but the block to its own block
    attr_accessor :contexts # [[Resource, Block]]

    # Current Resource object
    def context = @contexts.last.first

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
      r = yield
      @contexts.pop
      r
    end

    def dump
      puts "Compiler"
      indent {
        puts "variables"; indent { puts variables.map { |k,v| "#{k}: #{v}" } }
        puts "resource:"
        indent {
          puts "present:"; indent { puts present.map { "#{_1} (#{resource(_1).classname})" } }
          puts "absent:"; indent { puts absent }
          puts "unknown:"; indent { puts unknown }
        }
        if unresolved.empty?
          puts "unresolved: []"
        else
          puts "unresolved (#{unresolved.size}):"
          indent {
            unresolved.each { |node| puts "#{node.token.location}: #{node.unresolved_uid} #{node.classname}" }
          }
        end
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
