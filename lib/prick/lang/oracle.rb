
module Prick::Lang
  class Oracle
    include ErrorFunctions

    # Stack of contexts
    attr_accessor :contexts # [Resource]

    # Current Resource object
    def context = @contexts.last

    def initialize(variables)
      @contexts = []
      @variables = variables
      @resources = {}
    end

    def uid(ident)
      constrain ident, String
      (ident.index('.') ? ident : [context.uid, ident].compact.join("."))
    end

    # Execute block with the given context
    def scope(context, &block)
      constrain context, Idr::Resource
      @contexts.push context
      r = yield
      @contexts.pop
      r
    end

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
      }
    end

  private
    def entry(uid)
      constrain uid, String
      @resources.key?(uid) ? @resources[uid] : (@resources[uid] = nil)
    end
  end
end

