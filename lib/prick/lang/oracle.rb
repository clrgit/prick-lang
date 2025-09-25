
module Prick::Lang
  # Global knowledge
  #
  # Runtime values are symbols - :cmd, :env, :user and Resources are strings,
  # eg. 'schema.provide_resource'
  #
  class Oracle
    # Runtime constants
    attr_reader :constants # Symbol => String
    def cmd = @constants[:cmd]
    def env = @constants[:env]
    def user = @constants[:user]

    # Resources
    attr_reader :resources
    def present = @resources.filter_map { _2 and _1 }
    def absent = @resources.filter_map { ! _2.nil? && ! _2 and _1 }
    def known = @resources.filter_map { !_2.nil? and _1 }
    def unknown = @resources.filter_map { _2.nil? and _1 }

    def present?(uid) = (entry(uid) && true || false)
    def absent?(uid) = (entry(uid) || false) && true
    def known?(uid) = !entry(uid).nil?
    def unknown?(uid) = entry(uid).nil?

    def initialize(cmd, env, user)
      @constants = { cmd: cmd, env: env, user: user }
      @resources = {}
    end

    def [](key) = entry(key)

    def []=(uid, present)
      constrain present, true, false, nil
      !@resources.key?(uid) or raise ArgumentError "Duplicate key"
      @resources[uid] = present
    end

    # Return uids of true/false/nil entries

    def falsify_unknown
      unknown.each { |key| @resources[key] = false }
    end

    def dump
      puts "Oracle"
      indent {
        puts "constants"; indent { puts constants.map { |k,v| "#{k}: #{v}" } }
        puts "resources:"
        indent {
          puts "present: #{present.inspect}"
          puts "absent: #{absent.inspect}"
          puts "unknown: #{unknown.inspect}"
        }
      }
    end

  private
    def entry(uid) = @resources.key?(uid) ? @resources[uid] : (@resources[uid] = nil)
  end
end

