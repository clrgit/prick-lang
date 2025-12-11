
module Prick::Command
  class PWD < Command
    def run
      puts settings.database if settings.database
    end
  end
end


