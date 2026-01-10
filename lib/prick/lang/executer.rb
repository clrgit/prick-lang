
module Prick::Lang
  # TODO
  #   Handle schema commands
  #   Collect fox files
  #
  class Executer < CompilerProcess
    include Prick
    include ErrorFunctions
    include Prick::Lang::Timer

    using String::Text

    # Singleton instance
    def self.instance = @@INSTANCE

    attr_reader :bash # Bash::Bash object
    attr_reader :source # Executed postgres source if settings.log? is true

    forward_to :settings, :status

    def initialize
      @@INSTANCE = self
    end

    def execute
      ShellOpts.verb "Execute", newline: false
      t0 = Time.now

      # We delay initialization of the Bash object until here because we can't
      # access the #compiler object from #initialize
      @bash = Bash::Bash.new(bash_environment)
      @source = nil
      @status = false

      # Setup unit objects for #execute
      Unit::Node.conn = conn
      Unit::Node.bash = @bash

      # Create new PRICK.BUILDS record

      # Clear PRICK.RESOURCES that are marked for rebuild

      # Setup logger if requested
      proc = lambda { |arg| $stderr.puts arg.sub(/\n\s*\n/m, "\n") + ";" }
      logger = settings.log? && !conn.log? ? proc : nil

      begin
        settings.create_database_state
        settings.status = false

        # Execute units
        conn.with(log: logger) {
          units.each { |unit| unit.execute }
        }

        settings.status = true
      ensure
        dt = Time.now - t0
        settings.execute_duration = dt
        settings.update_database_state
      end

      ShellOpts.verb " (#{ftime dt})"
    end

    def inspect = "#<#{self.class} ...>"

  private
    # Singleton bash(1) environment (Hash). It is injected into the enviroment
    # of subprocesses
    def bash_environment
      @@BASH_ENVIRONMENT ||= begin
        # Path
        hash = { "PATH" => settings.executable_search_path }

        # Directories
        hash.merge({
          "PRICK_DIR" => settings.project_dir,
          "PRICK_DATABASE_CACHEDIR" => settings.database_cache_dir
        })

        # Directories from settings.dirs
        Prick::PROJECT_DIR_ATTRS.each { |attr| hash["PRICK_#{attr.upcase}DIR"] = settings.dirs[attr] }

        # Simple attributes
        attrs = [:name, :title, :version, :database, :username, :environment, :verbose?, :dryrun?, :log?]
        for attr in attrs
          hash["PRICK_#{attr.to_s.sub("?", "").upcase}"] = settings.send(attr).to_s
        end

        # Timestamp
        hash["PRICK_TIMESTAMP"] = settings.created_at.strftime("%F %T %Z")

        # Targets
        hash["PRICK_TARGETS"] = compiler.targets.join(" ")

        # Final result
        hash

#       TODO
#       # PRICK_ENVIRONMENT_* variables. Only defined if the environment is known
#       if !Prick.state.environment.nil? && environments.key?(environment)
#         hash.merge! environments[environment].bash_environment
#       end
      end
    end

    @@BASH_ENVIRONMENT = nil
  end
end

