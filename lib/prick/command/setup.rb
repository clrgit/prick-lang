
module Prick::Command
  class Setup < Command
    forward_to :settings, :database, :username, :environment

    # Command line syntax
    #     -- DATABASE [ENVIRONMENT]
    #     -- USERNAME DATABASE ENVIRONMENT
    #
    def initialize(opts, args)
      case args.size
        when 1; username = database = environment = args.first
        when 2; database, environment = *args; username = database
        when 3; username, database, environment = *args
      else
        args.expect(1..3) # Generates a inoa error
      end

      super \
          "setup", opts, args,
          database: database, username: username, environment: environment,
          load_files: [:environment_file],
          save_files: [:database_state_file]
    end

    def run
      Database.ensure database, username
      Database.init
      settings.save_build_state
      settings.save_database_state
    end
  end
end
