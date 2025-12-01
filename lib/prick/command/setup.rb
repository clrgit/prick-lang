
module Prick::Command
  class Setup < Command
    # DATABASE [ENVIRONMENT]
    # USERNAME DATABASE ENVIRONMENT
    def initialize(opts, args)
      case args.size
        when 1; username = database = environment = args.first
        when 2; database, environment = *args
        when 3; username, database, environment = *args
      else
        args.expect(1..3) # Generates a inoa error
      end

      super \
          "setup", opts, args,
          database: database, username: username, environment: environment,
          reflections_file: false,
          database_state_file: false

    end

    def run
#     create_database(PRICK_DATABASE, PRICK_USERNAME, PRICK_ENVIRONMENT)
#     set_database(PRICK_DATABASE, PRICK_ENVIRONMENT)
      state.save_database_state
    end
  end
end
