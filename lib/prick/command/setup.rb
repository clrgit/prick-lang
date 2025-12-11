
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
      FileUtils.mkdir_p settings.dirs.database_cache
      settings.save_prick_state
      settings.save_database_state
    end
  end
end
