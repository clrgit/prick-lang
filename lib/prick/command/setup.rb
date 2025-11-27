
module Prick::Command
  class Setup < BareCommand
    def initialize(opts, args)
      super "setup"
      case args.size
        when 1; username = database = environment = args.first
        when 2; database, environment = *args
        when 3; username, database, environment = *args
      else
        args.expect(1..3) # Generates a inoa error
      end
      Prick.initialize(database: database, username: username, environment: environment)
    end

    def run
#     create_database(PRICK_DATABASE, PRICK_USERNAME, PRICK_ENVIRONMENT)
#     set_database(PRICK_DATABASE, PRICK_ENVIRONMENT)
      Prick.save_state
    end
  end
end
