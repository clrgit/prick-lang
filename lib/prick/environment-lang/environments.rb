module Prick::EnvironmentLang
  class Environments
    # Supported variable types
    TYPES = %w(BOOLEAN STRING LIST TEXT)

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

    def initialize
      @types = @@TYPES.dup
      @environments = {}
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
    @@TYPES = { comment: "STRING", inherit: "LIST", build: "TEXT" }
    @@PRICK_VARIABLES = @@TYPES.keys
  end
end

