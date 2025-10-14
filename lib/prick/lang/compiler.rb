
module Prick::Lang
  class Compiler
    include ErrorFunctions

    attr_reader :dir # Current directory when the compiler was invoked
    attr_reader :file # Start file. Only used in error messages. May be nil, initialized by #parse if so
    attr_reader :parser # Initialized by #parse
    attr_reader :analyzer # Initialized by #analyze

    def ast = @parser.ast # Ast::Program. Initialized by #parse
    def idr = @analyzer.idr # Idr::Program. Initialized by #analyzer

    def initialize(file = nil, variables: {})
#     @@INSTANCE.nil? or raise ArgumentError, "Compiler is a singleton"
      @@INSTANCE = self
      @dir = Dir.getwd
      @dir_pathname = Pathname.new(@dir) # pre-computed, used in #userpath
      @file = file
      @variables = variables
      @parser = Parser.new
      @analyzer = Analyzer.new
      @resources = {}
      @unresolved = []
      @requires = []
      @contexts = []
    end

    # Singleton instance
    def self.instance = @@INSTANCE

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
    # General methods
    #

    def parse(file, lines = nil)
      @file ||= file
      @parser.parse(file, lines)
    end

    def analyze
      @analyzer.analyze
    end

    def compile(file, lines = nil)
      time "Parsing #{file}" do
        parse(file, lines)
      end

      time "Analyzing" do
        analyze
      end

#     puts "Dumping"
#     program.dump
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

    # Map from uid to Idr resource object, false if marked absent,
    # and nil if unknown
    attr_reader :resources # UID String => Idr::Node/false/nil

    # Unresolved nodes
    attr_accessor :unresolved # [Unresolved]

    # Resource associated with the given uid. Returns a Idr::Node object, true,
    # or nil
    def resource(uid) = @resources[uid]

    # Add an unknown resource if not present. Return the uid
    def ensure(value)
      constrain value, Ast::Value
      uid = self.uid(value.value)
      @resources[uid] = nil if !@resources.key?(uid)
      uid
    end

    # Add a present resource. It is an error if the resource is absent but not
    # if it is unknown
    def add(resource)
      constrain resource, Idr::Resource
      uid = resource.uid
      if !@resources[uid].nil?
        if @resources[uid]
          error resource.token, "Redefinition of '#{uid}'"
        else
          error resource.token, "'#{uid}' has been marked absent"
        end
      end
      @resources[uid] = resource
    end

    # Lists of present, absent, known, or unknown resources
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

    def mark_unknown_absent = unknown.each { |key| @resources[key] = false }

    #
    # Requirements (FIXME Unused)
    #

    # Require commands. Used by the #analyzer to check references
    attr_accessor :requires

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
        puts "resources:"
        indent {
          puts "present:"; indent { puts present }
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

  private
    @@INSTANCE = nil

    def entry(uid)
      constrain uid, String
      @resources.key?(uid) ? @resources[uid] : (@resources[uid] = nil)
    end
  end
end
