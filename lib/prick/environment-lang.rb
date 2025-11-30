
require 'set'
require 'dsort'

require_relative 'ext/x_yaml'

module Prick::EnvironmentLang
  class CompileError < Error; end
end

require_relative 'environment-lang/environment.rb'
require_relative 'environment-lang/environments.rb'
require_relative 'environment-lang/compiler.rb'

module Prick::Environment
  def self.compile(yaml) = Compiler.compile(yaml)
end

__END__

# TODO
#   o Add a CODE type
#   o super
module Prick::Environment
  class Environment
    # The enclosing Environments object. Used in #types
    attr_reader :environments

    # Environment name (String)
    attr_reader :name

    # List of names of inherited environments
    def inherit = assignments[:inherit]

    # List of directly inherited environment objects. Assigned by the
    # analyzer
    attr_accessor :parents

    # Ancestors (array of Environment objects) sorted in dependency order
    attr_accessor :ancestors

    # The ancestor that defines the build attribute or nil if ambigous.
    # Assigned by the analyzer
    attr_accessor :super_environment

    def has_super?() = !super_environment.nil?

    # Map from variable identifier to the environment that defines the value.
    # This assumes there are no ambigous assignments
    def assigners
      @assigners ||= begin
        effective_variables.keys.map { |ident|
          if assignments.key?(ident)
            [ident, self]
          else
            [ident, ancestors.reverse.find { |env| env.assignments.key?(ident) }]
          end
        }.to_h
      end
    end

    # Environment comment
    def comment = assignments[:comment]

    # Map from variable identifier (Symbol) to type. Type is one of the strings
    # listed in Environments::TYPES
    def types() = @environments.types

    # Map from variable identifier (Symbol) to value. Inherited variables are not
    # included in #assignments
    attr_reader :assignments

    # Return true if the environment assigns an attribute
    def assign?(ident) = @assignments.key?(ident)

    # Map from variable identifier (Symbol) to effective value. Initially equal
    # to #assignments but are later augmented or merged with the corresponding
    # assignments from inherited environments
    attr_accessor :effective_variables

    def initialize(environments, name, assignments)
      constrain environments, Environments
      constrain name, String
      constrain assignments, { Symbol => Object }
      @environments = environments
      @name = name
      @assignments = assignments
      @assignments[:inherit] ||= []
      @effective_variables = assignments.transform_values { |v| v.dup } # Deep-dup
    end

    forward_to :effective_variables, :key?, :[], :[]=, :to_h, :empty?, :size, :each, :map

    def bash() = "build_#{name}" # FIXME build has been out-commented
    def super_bash() = (has_super? ? "build_#{name}_super" : nil) # FIXME same
    def bash_environment
      effective_variables.map { |ident, value|
        ["PRICK_ENVIRONMENT_#{ident.upcase}", value]
      }.to_h
    end

    def inspect = "#<#{self.class} @name=#{@name}>"

    def dump
      puts "#{name}:"
      indent {
        self.each { |ident,val|
# FIXME
#         if ident == :build
#           puts "super: #{super_environment&.name || 'false'}"
#         end
          assigner = assigners[ident]&.name || name
          assigner_str = (assigner != name ? " (#{assigner})" : "")
          if types[ident] == "TEXT"
            puts "#{ident}#{assigner_str}:"
            indent { puts val }
          else
              puts "#{ident}#{assigner_str}: #{val.inspect}"
          end
          if ident == :inherit
            puts "ancestors: #{ancestors.map(&:name).inspect}"
          end
        }
      }
    end
  end
end

