
module Prick::Command
  class PWD < Command
    forward_to :settings, :database

    # Command line syntax
    #     pwd 
    #
    def initialize(opts, args)
      super \
          "pwd", opts, args,
          load_files: [:database_state_file]
    end

    def run
      puts settings.database if settings.database
    end
  end
end


