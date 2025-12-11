module Prick::Command
  class Info < Command
    def run
      h = settings.database_state.to_h
      puts "project: #{h[:name]}"
      indent {
        puts "prick: #{settings.prick_version}"
        puts "database: #{settings.database || 'nil'}"
        puts "id: #{h[:id] || 'nil'}"
        keys = h.keys - [:id, :name]
        keys.each { |k|
          puts "#{k}: #{h[k] || 'nil'}"
        }
      }
    end
  end
end

