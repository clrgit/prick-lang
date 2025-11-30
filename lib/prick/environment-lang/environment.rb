
# TODO
#   o Add a CODE type
#   o super
module Prick::EnvironmentLang
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

__END__

# TODO
#   o Add a CODE type
#   o super
module Prick
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

  class Environments
    # Map from environment name to Environment object
    attr_reader :environments

    # Environments acts like a hash from name to Environment object
    forward_to :@environments, :[], :[]=, :key?, :keys, :values, :each, :map

    # Maps from variable name (Symbol) to type (String)
    attr_reader :types

    # List of all variables (Symbol). Same as 'types.keys'
    def variables = types.keys

    # List of variable identifiers defined by prick
    def prick_variables = @@PRICK_VARIABLES

    # List of user defined variables
    def user_variables = variables - prick_variables

    def initialize(hash)
      @types = @@TYPES.dup
      @environments = {}
      parse_variables(hash)
      parse_environments(hash)
      analyze
    end

    def bash_environment

    end

    # FIXME build has been out-commented
    def bash_command(environment = nil)
      raise "Not available right now"
      constrain environment, String, nil
      if environment
        env = self[environment] or raise "Unknown environment: '#{environment}'"
        envs = [env]
      else
        envs = environments
      end

      puts "### SCRIPT by #{File.basename(__FILE__)}"

      puts %(

        ## STACK METHODS - ChatGPT

        # global variable
        super_stack=()

        function push_super_stack() {
          local method=$1
          super_stack+=($method)
        }

        function pop_super_stack() {
          super_stack=("${super_stack[@]::${#super_stack[@]}-1}")
        }

        function super() {
          eval ${super_stack[-1]}
        }
      ).align

      puts "## ENVIRONMENT METHODS"
      puts
      for name, env in environments
        puts "function build_#{name}() {"
        assigner = env.assigners[:build]
        indent {
          if assigner == env
            if env.has_super?
              puts "push_super_stack #{env.super_bash}"
            end
            puts env[:build]
            if env.has_super?
              puts "pop_super_stack"
            end
          else
            puts "build_#{assigner.name} # default super"
          end
        }
        puts "}"
        puts
        if env.has_super? && assigner == env
          puts "build_#{name}_super() { build_#{env.super_environment.name}; }"
          puts
        end
      end

      if environment
        puts "## DEFAULT BUILD METHOD"
        puts
        puts "function build() { build_#{environment}; }"
        puts
      end
    end

    def dump
      puts "Types"
      indent { types.each { |k,v| puts "#{k}: #{v}" } }
      puts
      puts "Environments"
      indent { environments.values.each { |env| env.dump } }
    end

  private
    TYPES = %w(BOOLEAN STRING LIST TEXT)
    @@TYPES = { comment: "STRING", inherit: "LIST", build: "TEXT" }
    @@PRICK_VARIABLES = @@TYPES.keys

    def parse_variables(yaml)
      decls = yaml.delete("variables") || ""
      decls.split.each { |decl|
        decl =~ /^(.*):(.*)$/ or ShellOpts.error "Illegal declaration of '#{decl}' in variable list"
        name, type = $1.to_sym, $2
        type = type.upcase
        TYPES.include?(type) or ShellOpts.error "Illegal type '#{type}'"
        @types[name] = type
      }
    end

    def parse_environments(yaml)
      yaml.each { |environment, variables|
        assignments = variables.map { |ident, value|
          ident = ident.to_sym
          case types[ident]
            when "BOOLEAN"
              [TrueClass, FalseClass].include?(value.class) or raise "Illegal value for #{ident}: #{value}"
            when "STRING"
              ; # nop
            when "LIST"
              value = value&.split || []
            when "TEXT"
              value = (value == false ? "false" : value.chomp)
            when nil
              ShellOpts.error "Unknown variable '#{ident}'"
          else
            raise ArgumentError
          end
          [ident, value]
        }.to_h
        @environments[environment] = Environment.new(self, environment, assignments)
      }
    end

    def analyze
      # Assign Environment#parent
      values.each { |env|
        env.parents = env.inherit.map { |name|
          self[name] or raise ArgumentError, "Can't find '#{name}' environment referred from '#{name}'"
        }
      }

      # Sort environment names in dependency order
      deps = self.map { |name, env| [name, env.inherit] }
      sorted_environments = DSort.dsort(deps).map { |name| self[name] }

      # Compute effective attribute values by processing environments in
      # dependency order so that all inherited environments are computed before
      # the current environment
      for env in sorted_environments
        for inherited in env.parents
          for ident, type in types
            next if ident == :comment # Comments are not inherited
            next if !inherited.key?(ident)
            value = inherited[ident]
            case type
              when "BOOLEAN"; env[ident] = value if !env.key?(ident)
              when "STRING"; env[ident] ||= value
              when "LIST";
                  next if ident == :inherit # Does not accumulate
                  # FIXME !inherited.key? should prevent env[ident].nil?
                  env[ident] = (value + (env[ident] || [])).uniq
              when "TEXT"; env[ident] = env[ident] || value
            else
              raise ArgumentError
            end
          end
        end
      end

      # Assign #ancestors
      sorted_indexes = sorted_environments.map.with_index { |env, idx| [env.name, idx] }.to_h
      for env in sorted_environments
        env.ancestors =
          (env.parents + env.parents.map(&:ancestors))
            .flatten
            .uniq
            .sort_by { |env| sorted_indexes[env.name] }
      end

      # Check ambigous string, text, and boolean definitions (:initial is never
      # ambigous and :comment is special). TODO: Find a faster algorithm
      for env in sorted_environments
        for ident, value in env.effective_variables
          type = types[ident]

          # Ignore mergeable types (LIST)
          next if !%w(STRING TEXT BOOLEAN).include?(type)

          # Ignore :initial and :comment
          next if [:initial, :comment].include?(ident)

          # Ignore if variable is assigned in the current environment and not the
          # special :build attribute
#         next if env.assignments.key?(ident) && ident != :build
          next if env.assignments.key?(ident)

          # Pool of ancestors. When an environment assigns a value, all ancestors
          # of the environment are removed from the pool. If any remaining environment
          # also assigns the variable, the definition is ambigous. 'pool' and
          # 'queue' works together to provide a set of environments with
          # queue-like properties
          pool = Set.new(env.ancestors)

          # Queue of ancestors. It is used to iterate the pool environments in
          # reversed dependency order
          queue = env.ancestors.reverse

          # Look for the first environment that assigns the variable
          while ancestor = queue.shift
            next if !pool.include?(ancestor)
            if ancestor.assignments.key?(ident)
              # Remove all ancestors that are inherited by the assigning environment
              pool -= ancestor.ancestors
#             if ident == :build
#               env.super_environment = ancestor #if ident == :build
#             end
              break
            end
          end

          # Check that remaining environments do not also assign the variable.
          # The :block attribute is checked even if defined in the current
          # environment to be able to tell if 'super' is ambigous
          while ancestor = queue.shift
            next if !pool.include?(ancestor)
            if ancestor.assign?(ident)
#             if ident == :build && env.assign?(:build)
#               env.super_environment = nil
#             else
                raise ArgumentError, "Ambigious definition of '#{ident}' in #{ancestor.name} environment"
#             end
            end
          end
        end
      end
    end
  end
end

