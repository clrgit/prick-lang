
module Prick::Lang
  class Oracle
    # Current schema. Maintained by the #analyzer
    attr_accessor :schema

    def uid(value)
      l, r = value.split(".")
      (r ? [l,r] : [schema.ident, l]).join(".")
    end

    def create_uid(value)
      uid = self.uid value
      self[uid] = true
      uid
    end

    def resolve_uid(uid, value)
      @resources.key?(uid) or raise ArgumentError, "Unknown key '#{uid}'"
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
    def []=(uid, present)
      constrain present, true, false, nil
      if value = @resources[uid]
        !present.nil? && value == false or
            raise ArgumentError, "Illegal reassignment of key '#{uid}' to #{present.inspect}"
      end
      @resources[uid].nil? or
      @resources[uid] = present
    end

    # Return uids of true/false/nil entries

    def mark_unknown_absent
      unknown.each { |key| @resources[key] = false }
    end

    def dump
      puts "Oracle"
      indent {
        puts "variables"; indent { puts variables.map { |k,v| "#{k}: #{v}" } }
        puts "resources:"
        indent {
          puts "present: #{present.inspect}"
          puts "absent: #{absent.inspect}"
          puts "known: #{known.inspect}"
          puts "unknown: #{unknown.inspect}"
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

