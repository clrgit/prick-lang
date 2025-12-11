module Prick::Command
  class CD < Command
    attr_reader :database

    # Command line syntax
    #     cd DATABASE
    #
    def initialize(opts, args)
      @database = args.expect(1)
      super opts, args
    end

    def run
      settings.save_prick_state database: database
    end
  end
end

