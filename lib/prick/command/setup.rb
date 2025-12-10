
module Prick::Command
  class Setup < Command
    forward_to :settings, :database, :username, :environment

    # Command line syntax
    #     -- DATABASE [ENVIRONMENT]
    #
    def initialize(opts, args)
      database, environment = args.expect(1..2)
      environment = database

      super \
          "setup", opts, args,
          database: database, environment: environment
    end

    def run
      Database.ensure database
      Database.init
      settings.save_build_state
      settings.save_database_state
    end
  end
end
