module Prick::Lang
  class Generator < CompilerProcess
    def dump
      puts "Generator"; indent {
        puts "Idr units: #{units.size}"
        puts "Meta"; indent {
          puts "Schemas: #{meta.schemas.join(', ')}"
          puts "Tables: #{meta.tables.map { _1.join('.') }.join(', ')}"
        }
        puts "Phases"; indent {
          puts "affected: #{affected_phases.map &:ident}"
          phases.each { |k,v|
            puts "#{k.downcase}: #{v.size}"
          }
        }
        puts "Schemas"; indent {
          puts "targets: #{target_schemas.map &:ident}"
          puts "seeds: #{seed_schemas.map &:ident}"
          puts "build: #{build_schemas.map &:ident}"
          puts "invalid: #{invalid_schemas.map &:ident}"
          puts "preserve: #{preserve_schemas.map &:ident}"
          puts "affected: #{affected_schemas.map &:ident}"
        }
        puts "Executable units: #{execute_units.size}"
      }
    end
  end
end


