module Prick::Command
  class CD < Command
    forward_to :settings, :database, :database=

    # Command line syntax
    #     cd DATABASE
    #
    def initialize(opts, args)
      database = args.expect(1)
      super \
          "cd", opts, args,
          database: database
      settings.username = Database.owner(database) # Requires db access so have to go after super
    end

    def run
      Database.prick? or error "Not a prick database - '#{settings.database}'"
      settings.load_build_state
      settings.environment = settings.build.environment
      settings.save_database_state
      settings.reset_compiler_state
    end
  end
end

