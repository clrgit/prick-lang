
module Prick::Lang
  class Oracle
    include ErrorFunctions

    # Current schema. Maintained by the #analyzer
    attr_accessor :schema

    def uid(name)
      l, r = name.split(".")
      (r ? [l,r] : [schema.ident, l]).join(".")
    end

    # Add an unknown resource if not present. Return the uid
    def ensure(value)
      constrain value, Ast::Value
      uid = self.uid(value.value)
      @resources[uid] = nil if !@resources.key?(uid)
      uid
    end

    # Add a present resource and return uid. It is an error if the resource is
    # absent but not if it not known
    def add(value)
      constrain value, Ast::Value
      uid = self.uid(value.value)
      if !@resources[uid].nil?
        if @resources[uid]
          p @resources[uid]
          error value, "Redefinition of '#{uid}'"
        else
          error value, "'#{uid}' has been marked absent"
        end
      end
      @resources[uid] = true
      uid
    end

    def resolve_uid(uid, node)
      constrain node, Idr::Resource
      @resources[uid] = node
    end

    # Runtime variables
    attr_reader :variables # Symbol => String
    def cmd = @variables[:cmd] # FIXME Not needed any longer
    def env = @variables[:env]
    def user = @variables[:user]

    # Resources
    attr_reader :resources # UID String => true/false/nil
    def present = @resources.filter_map { _2 and _1 }
    def absent = @resources.filter_map { ! _2.nil? && ! _2 and _1 }
    def known = @resources.filter_map { !_2.nil? and _1 }
    def unknown = @resources.filter_map { _2.nil? and _1 }

    def present?(uid) = (entry(uid) && true || false)
    def absent?(uid) = (entry(uid) || false) && true
    def known?(uid) = !entry(uid).nil?
    def unknown?(uid) = entry(uid).nil?

    def initialize(variables)
      @variables = variables
      @resources = {}
    end

    def [](key) = entry(key)

    # Can assign true/false to nil, and true to false
#   def []=(uid, present)
#     constrain present, true, false, nil
#     !@resources.key?(uid) || !present.nil? && @resources[uid] == false or
#         raise ArgumentError, "Illegal reassignment of key '#{uid}' to #{present.inspect}"
#     @resources[uid] = present
#   end

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
      }
    end

  private
    def entry(uid)
      constrain uid, String
      @resources.key?(uid) ? @resources[uid] : (@resources[uid] = nil)
    end
  end
end

