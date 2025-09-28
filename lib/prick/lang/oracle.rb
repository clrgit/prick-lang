
module Prick::Lang
  class Oracle
    include ErrorFunctions

    # . Maintained by the #analyzer
    attr_accessor :contexts

    # Current containing Resource object
    def context = @contexts.last

    def initialize(variables)
      @contexts = []
      @variables = variables
      @resources = {}
    end

    # Execute block with the given context
    def scope(context, &block)
      @contexts.push context
      r = yield
      @contexts.pop
      r
    end

    def uid(name)
      l, r = name.split(".")
      (r ? [l,r] : [context&.ident, l].compact).join(".")
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
#   def add(value)
#     constrain value, Ast::Value
#     uid = self.uid(value.value)
#     if !@resources[uid].nil?
#       if @resources[uid]
#         error value, "Redefinition of '#{uid}'"
#       else
#         error value, "'#{uid}' has been marked absent"
#       end
#     end
#     @resources[uid] = true
#     uid
#   end

    def add(ref, &block)
      constrain ref, Ast::Reference, Ast::Ident
      uid = self.uid(ref.value)
      node = yield(uid)
      if !@resources[uid].nil?
        if @resources[uid]
          error value, "Redefinition of '#{uid}'"
        else
          error value, "'#{uid}' has been marked absent"
        end
      end
      @resources[uid] = node
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

