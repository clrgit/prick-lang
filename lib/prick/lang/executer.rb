
module Prick::Lang
  # TODO
  #   Handle schema commands
  #   Collect fox files
  #

  class Executer < CompilerProcess
    using String::Text

    def initialize
    end

    def execute
      for unit in units
        case idr = unit.node
          when Idr::SqlCommand
            sql_command(idr.source.value)
          when Idr::FoxCommand
            fox_command(idr.path)
          when Idr::FileCommand
            file_command(idr.path)
          when Idr::ExternalCommand
            idr.kind == :EXEC ? exec_command(idr.source.value) : eval_command(idr.source.value)
          when Idr::CopyCommand
            copy_command idr.tables.map(&:value)
          when Idr::SyncCommand
            sync_command idr.table, idr.key, idr.id_table || idr.source.value
          when Idr::PrepareCommand
            prepare_command idr.table, idr.key, idr.id_table || idr.source.value
          when Idr::MarkCommand
            mark_command idr.uid
          else
            puts "Oops #{unit.node.class}"
        end
      end
    end

  private
    def commit_command
      log "COMMIT"
      run { db.commit }
    end

    # Operations
    def exec_command(cmd)
      commit_command
      log "EXEC", cmd
      run { system(cmd) }
    end

    def eval_command(cmd)
      commit_command
      log "EVAL", cmd
      run { system(cmd) }
    end

    def sql_command(source)
      log "SQL", source
      run { db.exec(source) }
    end

    def file_command(filename)
      log "FILE #{filename}"
      run { sql(IO.read filename) }
    end

    def fox_command(filename)
      commit_command
      log "FOX #{filename}"
      run { system("fox -d #{prick_database} -U #{prick_username} \#{files}") }
    end

    def copy_command(tables)
      commit_command
      log "COPY #{tables.join(', ')}"
      run {
        system("pg-merge copy ...")
      }
    end

    def sync_command
      commit_command
      log "SYNC"
      system("pg-merge sync ...")
    end

    def prepare_command
      commit_command
      log "PREPARE"
      system("pg-merge prepare ...")
    end

    def mark_command(uid)
      log "MARK #{uid}"
    end

    def run(&block)
#     yield if !compiler.dryrun
    end

    def log(s, t = "")
      if compiler.log?
        puts s
        indent { puts t } if !t.empty?
      end
    end
  end
end

