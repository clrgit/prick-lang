
module Prick::Lang

  # TODO
  #   Handle schema commands
  #   Collect fox files
  #

  class Executer < CompilerProcess
    using String::Text

    def commit
      db.commit
    end

    # Operations
    def exec(cmd)
      system(cmd)
    end

    def eval(cmd)
    end

    def sql(source)
      db.exec(source)
    end

    def file(filename)
      sql(IO.read filename)
    end

    def fox
      system("fox -d #{prick_database} -U #{prick_username} \#{files}")
    end

    def copy
      commit
      system("pg-merge copy ...")
    end

    def sync
      system("pg-merge sync ...")
    end

    def prepare
      system("pg-merge prepare ...")
    end

    def handled
    end

    def mark
    end

    def execute
      for unit in units
        case idr = unit.node
#         when Idr::FileCommand
          when Idr::SqlCommand
            puts "sql('#{idr.source.value}')"

          when Idr::FoxCommand
            puts "fox('#{idr.path}')"

          when Idr::FileCommand
            puts "file('#{idr.path}')"

          when Idr::ExternalCommand
            cmd = idr.kind == :EXEC ? "exec" : "eval"
            puts "#{cmd}('#{idr.source.value}')"
          when Idr::CopyCommand, Idr::HandledCommand
            cmd = idr.is_a?(Idr::CopyCommand) ? "copy" : "handled"
            puts "#{cmd}(#{idr.tables.map(&:value).join(", ")})"
          when Idr::SyncCommand, Idr::PrepareCommand
            cmd = idr.is_a?(Idr::SyncCommand) ? "sync" : "prepare"
            print "#{cmd}(#{idr.table}, #{idr.key}"
            if idr.id_table
              print ", #{idr.id_table}"
            elsif idr.source
              print ", '#{idr.source.value}'"
            end
            puts ")"
          when nil
            puts "BOOM"
          when Idr::MarkCommand
            puts "mark('#{idr.uid}')"
          else
            puts "#{unit.node.class}"
        end
      end
    end
  end
end

