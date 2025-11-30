
# TODO
#   o Add a CODE type
#   o super
module Prick::EnvironmentLang
  class Compiler
    # Compiled Environments object
    attr_reader :environments

    def initialize(yaml)
      constrain yaml, Hash
      @yaml = yaml.dup # Read/write copy of input yaml
      @environments = Environments.new
    end

    # Compile yaml and return an Environments object
    def compile
      parse_variables
      parse_environments
      analyze
      @environments
    end

    # Compile yaml and return an Environments object
    def self.compile(yaml) new(yaml).compile end

    def error(msg) = raise CompileError.new msg

    # Find variables declarations and build name-to-type hash
    def parse_variables
      decls = @yaml.delete("variables") || ""
      decls.split.each { |decl|
        decl =~ /^(.*):(.*)$/ or error "Illegal declaration of '#{decl}' in variable list"
        name, type = $1.to_sym, $2
        type = type.upcase
        Environments::TYPES.include?(type) or error "Illegal type '#{type}'"
        @environments.types[name] = type
      }
    end

    # Parse environment entries
    def parse_environments
      @yaml.each { |environment, variables|
        assignments = variables.map { |ident, value|
          ident = ident.to_sym
          case types[ident]
            when "BOOLEAN"
              [TrueClass, FalseClass].include?(value.class) or error "Illegal value for #{ident}: #{value}"
            when "STRING"
              ; # nop
            when "LIST"
              value = value&.split || []
            when "TEXT"
              value = (value == false ? "false" : value.chomp)
            when nil
              ShellOpts.error "Unknown variable '#{ident}'"
          else
            raise InternalError
          end
          [ident, value]
        }.to_h
        @environments.environments[environment] = Environment.new(self, environment, assignments)
      }
    end

    def analyze
      # Assign Environment#parent
      @environments.values.each { |env|
        env.parents = env.inherit.map { |name|
          @environments[name] or error "Can't find '#{name}' environment referred from '#{name}'"
        }
      }

      # Sort environment names in dependency order
      deps = @environments.map { |name, env| [name, env.inherit] }
      sorted_environments = DSort.dsort(deps).map { |name| @environments[name] }

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
              raise InternalError
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
                error "Ambigious definition of '#{ident}' in #{ancestor.name} environment"
#             end
            end
          end
        end
      end
    end
  end
end

