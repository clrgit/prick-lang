
module Prick::Command
  class Setup < Command
    forward_to :settings, :database, :username, :environment

    # Setup database even if it exists
    attr_reader :force

    # Command line syntax
    #     -- [DATABASE] ENVIRONMENT
    #
    def initialize(opts, args)
      @force = opts.subcommand!.force || false
      environment, database = args.expect(1..2)
      database ||= environment
      super opts, args, database: database, environment: environment, load_database_state: false
    end

    def run
      !Database.exist?(database) || force or error "Won't overwrite existing database #{database}"
      Database.ensure database
      Database.init
      FileUtils.rm_rf settings.dirs.database_cache # To remove all existing state files
      FileUtils.mkdir_p settings.dirs.database_cache
      settings.save_prick_state
      settings.create_database_state
      settings.save_database_cache
    end
  end
end
