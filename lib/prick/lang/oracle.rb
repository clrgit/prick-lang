
module Prick::Lang
  class Oracle
    include ErrorFunctions

    # Runtime variables
    attr_reader :variables # Symbol => String

    # Resources
    attr_reader :resources # UID String => true/false/nil

    # Unresolved nodes
    attr_accessor :unresolved # Unresolved

    # Require commands. Used by the #analyzer to check references
    attr_accessor :requires

    # Stack of contexts and associated block. Block is usually equal to
    # resource.block but unresolved nodes sets the resource to the parent
    # resource but block to its own block
    attr_accessor :contexts # [[Resource, Block]]

    # Current Resource object
    def context = @contexts.last.first

    def initialize(variables)
      @variables = variables
      @resources = {}
      @unresolved = []
      @requires = []
      @contexts = []
    end

    def uid(ident)
      constrain ident, String
      (ident.index('.') ? ident : [context.uid, ident].compact.join("."))
    end

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

    # Add an unknown resource if not present. Return the uid
    def ensure(value)
#     puts "#ensure(#{value.inspect})"
#     puts "  value.value: #{value.value.inspect}"
#     puts "  uid: #{self.uid(value.value)}"
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

    # Resources
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

    def [](key) = entry(key)

    def mark_unknown_absent = unknown.each { |key| @resources[key] = false }

    def dump
      puts "Oracle"
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
    def entry(uid)
      constrain uid, String
      @resources.key?(uid) ? @resources[uid] : (@resources[uid] = nil)
    end
  end
end

