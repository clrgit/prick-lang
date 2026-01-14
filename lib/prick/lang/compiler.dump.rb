
module Prick::Lang
  class Compiler
    def dump
      puts "Compiler"
      indent {
        puts "timestamp: #{@timestamp&.strftime("%F %T %Z") || 'nil'}"
        puts "created_at: #{settings.created_at.strftime("%F %T %Z")}"
        pindent "variables:" do puts variables.map { |k,v| "#{k}: #{v}" } end
        pindent "sources:" do puts sources.keys end
        pindent "merge tables:" do
          for kind in Idr::MergeCommand::KINDS
            puts "#{kind.downcase}: #{merge_commands[kind].map(&:table).join(', ')}"
          end
        end
        pindent "resources ('*' - dirty):" do
          resources.sort_by(&:first).each { |uid, node|
            dirty = mode == :make && node.dirty? ? "*" : nil
            puts [uid, dirty, "(#{node.classname})"].compact.join(' ') + " #{node.ast.class}"
          }
        end

        pindent "nodes:" do
          kinds = [:dirty, :built, :excluded, :build, :make]
          methods = kinds.map { |k| [k, :"#{k}?"] }.to_h
          counts = kinds.map { |k| [k, 0] }.to_h
          idr.each { |node|
            for kind, method in methods
              counts[kind] += 1 if node.send(method)
            end
          }
          puts "all: #{counts.values.sum}"
          for kind in kinds
            puts "#{kind}: #{counts[kind]}"
          end
        end
      }
    end

    def dump_units
      units.each { |unit| puts "TODO" }
    end

    def dumpdeps = targets.each { resources[_1].dumpdeps }
    def dumpreqs = targets.each { resources[_1].dumpreqs }
    def dumprefs = idr.dumprefs

  private
    @@INSTANCE = nil

    def entry(uid)
      constrain uid, String
      @resources.key?(uid) ? @resources[uid] : (@resources[uid] = nil)
    end
  end
end

