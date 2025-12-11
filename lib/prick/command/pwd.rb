
module Prick::Command
  class PWD < Command
    forward_to :settings, :database

    def run
      puts settings.database if settings.database
    end
  end
end


