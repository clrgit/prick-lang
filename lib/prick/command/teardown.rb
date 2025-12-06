module Prick::Command
  class Teardown < Command
    forward_to :settings, :database

    attr_reader :keep_owner
    attr_reader :target_database

    # Command line syntax
    #     --keep-owner -- DATABASE
    #
    def initialize(opts, args)
      @keep_owner = opts.subcommand!.keep_owner || false
      @target_database = args.expect(1)
      super \
          "teardown", opts, args,
          load_files: [:database_state_file],
          super_conn: true
    end

    def run
      Database.drop(target_database, owner: !keep_owner) if Database.exist?(target_database)
      settings.reset_state if database == target_database
    end
  end
end

