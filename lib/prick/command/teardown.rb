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
      super opts, args
    end

    def run
      Database.drop(target_database, owner: !keep_owner) if Database.exist?(target_database)
      FileUtils.rm_rf File.join(settings.dirs.cache, @target_database)
      settings.save_prick_state database: nil if @target_database == settings.database
    end
  end
end

