module Prick::Command
  class CD < Command
    attr_reader :target_database

    # Command line syntax
    #     cd DATABASE
    #
    def initialize(opts, args)
      database = args.expect(1)
      super opts, args, database: database
    end

    def run
      if !settings.database_state
        if Database.prick?
          settings.get_database_state
          settings.save_database_state
        else
          error "Not a prick database '#{settings.database}'"
        end
      end
      settings.save_prick_state
    end
  end
end

