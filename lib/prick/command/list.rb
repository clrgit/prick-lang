
require_relative '../ext/fmt.rb'

module Prick::Command
  class List < Command
    attr_reader :kind
    attr_reader :format # :long or :short (the default)

    # Command line syntax
    #     --long -- [databases|environments|variables|users]
    #
    def initialize(opts, args)
      @format = opts.subcommand!.long? ? :long : :short
      @kind = args.expect(0..1)&.to_sym || :databases
      super opts, args
    end

    def run
      case kind
        when :databases; list_databases
        else raise
      end
    end

    def list_databases
      states = settings.load_database_cache

      if format == :short
        puts states.keys
      else
        # Timestamp of newest file under git control
        newest_file = Bash.command("ls -tr #{Git.list.join(" ")} | tail -1", stderr: false, fail: false).last
        fs_time = File.mtime(newest_file)

        # Git status
        git_branch = Git.branch.current
        git_rev = Git.id[0...8]

        headers = %w(database version branch rev environment built success state) + [" "]

        current_database_index = nil
        rows = states.each.with_index.map { |(database, state), index|
          # Created at
          built = state.created_at&.strftime("%Y-%m-%d %H:%M")

          # Add dirty flag
          rev = (state.clean ? " " : "+") + state.rev

          # Add current database marker
          if database == settings.database
            mark = "*"
            current_database_index = index
          else
            mark = ""
          end

          # Compute state
          #
          # State values:
          #   fail    Build failed
          #   clean   Success, can be reproduced
          #   ok      Success, can be reproduced but with noncomitted changes
          #   state   Success, can't be reproduced
          #
          if state.status == true
            if state.clean
              state_state = "clean"
            elsif state.branch == git_branch && state.rev == git_rev && fs_time <= state.created_at
              state_state = "ok"
            else
              state_state = "stale"
            end
          elsif state.status == false
            state_state = "fail"
          else
            state_state = nil
          end

          [
              database, state.version, state.branch, rev, state.environment,
              built, state.status, state_state, mark
          ]
        }

        Fmt.puts_table(headers, rows, bold: current_database_index)
      end
    end
  end
end


__END__

        puts Prick.databases
      else
        # Timestamp of newest file under git control
        newest_file = Command.command("ls -tr #{Git.list.join(" ")} | tail -1", stderr: false, fail: false).last
        fs_time = File.mtime(newest_file)

        git_branch = Git.branch.current
        git_rev = Git.id[0...8]

        rows = []
        current_database_row = nil
        Prick.databases { |database, conn|
          row = conn.record(%(
            select
                '#{database}' as "database", name, version, branch, rev, clean, environment, built_at, success
            from prick.versions
          ))

          # Detect if this is the current database
          if Prick.state.database == database
            is_current_database = true
            current_database_row = rows.size
          end

          # Clean repository
          clean = row.delete(:clean)

          if row[:success]
            same_revision = row[:branch] == git_branch && row[:rev] == git_rev
            up2date = fs_time <= row[:built_at]

            # Set state
            row[:state] =
                case [clean, same_revision, up2date]
                  in [true, true, true]; "clean"    # Built from clean repo
                  in [true, true, false]; "ok"      # Clean repo but doesn't include latest uncommitted changes
                  in [true, false, _]; "clean"      # Clean repo but different revision

                  in [false, true, true]; "edge"    # Dirty repo, work-in-progress
                  in [false, true, false]; "dirty"  # Dirty repo and doesn't include latest changes
                  in [false, false, _]; "stale"     # Dirty repo, no way back
                end
          elsif row[:success] == false
            row[:state] = "fail"
          else
            row[:state] = "-"
          end

          # Convert built_at to string
          row[:built_at] = row[:built_at]&.strftime("%Y-%m-%d %H:%M")

          # Add dirty flag
          row[:rev] = (clean ? " " : "+") + row[:rev]

          # Add current database marker
          last_column = (is_current_database ? "*" : "")

          rows << row.values + [last_column]
        }

        headers = %w(database project version branch rev environment built success state) + [" "]
        Fmt.puts_table(headers, rows, bold: current_database_row)
      end
    end

  end
end

module Prick::SubCommand
  def self.list_environments(format: :short)
    environments = Prick.state.environments.values.select { |env| env.comment }
    if format == :short
      puts environments.map(&:name)
    else
      headers = %w(Environment Description)
      rows = environments.map { |env| [env.name, env.comment] }
      Fmt.puts_table(headers, rows)
    end
  end

  def self.list_variables(format: :long, all: false)
    if format == :short
      puts Prick.state.bash_environment(all: all).keys
    else
      headers = %w(variable value)
      vars = Prick.state.bash_environment(all: all).reject { |k,v| k == "PATH" }
      rows = vars.map
#     rows = vars.map { |k,v|
#       if v.is_a?(Array)
#         if v.first&.is_a?(Array)
#           v = v.first
#         else
#           v = v.join(" ")
#         end
#       else
#         v = v.to_s
#       end
#
#       [k, v]
#     }
      Fmt.puts_table(headers, rows)
    end
  end

  def self.list_databases(format: :short)
    constrain format, :long, :short
    conn = State.connection
#   databases = conn.values "select datname from pg_database where datistemplate = false order by datname;"

    if format == :short
      puts Prick.databases
    else
      # Timestamp of newest file under git control
      newest_file = Command.command("ls -tr #{Git.list.join(" ")} | tail -1", stderr: false, fail: false).last
      fs_time = File.mtime(newest_file)

      git_branch = Git.branch.current
      git_rev = Git.id[0...8]

      rows = []
      current_database_row = nil
      Prick.databases { |database, conn|
        row = conn.record(%(
          select
              '#{database}' as "database", name, version, branch, rev, clean, environment, built_at, success
          from prick.versions
        ))

        # Detect if this is the current database
        if Prick.state.database == database
          is_current_database = true
          current_database_row = rows.size
        end

        # Clean repository
        clean = row.delete(:clean)

        if row[:success]
          same_revision = row[:branch] == git_branch && row[:rev] == git_rev
          up2date = fs_time <= row[:built_at]

          # Set state
          row[:state] =
              case [clean, same_revision, up2date]
                in [true, true, true]; "clean"    # Built from clean repo
                in [true, true, false]; "ok"      # Clean repo but doesn't include latest uncommitted changes
                in [true, false, _]; "clean"      # Clean repo but different revision

                in [false, true, true]; "edge"    # Dirty repo, work-in-progress
                in [false, true, false]; "dirty"  # Dirty repo and doesn't include latest changes
                in [false, false, _]; "stale"     # Dirty repo, no way back
              end
        elsif row[:success] == false
          row[:state] = "fail"
        else
          row[:state] = "-"
        end

        # Convert built_at to string
        row[:built_at] = row[:built_at]&.strftime("%Y-%m-%d %H:%M")

        # Add dirty flag
        row[:rev] = (clean ? " " : "+") + row[:rev]

        # Add current database marker
        last_column = (is_current_database ? "*" : "")

        rows << row.values + [last_column]
      }

      headers = %w(database project version branch rev environment built success state) + [" "]
      Fmt.puts_table(headers, rows, bold: current_database_row)
    end
  end

  def self.list_users
    puts State.connection.role.list(database: Prick.state.database)
  end

  def self.list_owners(format: :short)
    owners = {}
    Prick.databases.each { |database|
#     owner = super_conn.rdbms.exist?(d) ? super_conn.rdbms.owner(d) : d
      owner = super_conn.rdbms.owner(database)
      (owners[owner] ||= []) << database
    }
    if format == :short
      puts owners.keys
    else
      headers = %w(username databases) + [" "]
      rows = owners.map { |owner, databases|
        current_user_mark = (Prick.state.username == owner ? '*' : "")
        [owner, databases.join(","), current_user_mark]
      }
      Fmt.puts_table(headers, rows)
    end
  end
end



__END__

database                project version branch    rev       environment             built            success state
----------------------- ------- ------- --------- --------- ----------------------- ---------------- ------- -----
app_portal_frontend     mikras  0.4.84  dev       +4232f38f app_portal_frontend     2025-11-10 17:30 true    stale
ext                     Mikras  0.4.73  dev_plone  17f1a501 ext                     -                -       -
fdw                     Mikras  0.4.73  dev_plone +e6568b59 fdw                     -                -       -
import_acl_portal       mikras  0.4.84  dev       +f1a4b3db import_acl_portal       2025-11-13 15:40 true    stale
import_app_portal       mikras  0.4.84  dev       +f1a4b3db import_app_portal       2025-11-13 15:38 true    stale
import_auth_person      mikras  0.4.84  dev       +f1a4b3db import_auth_person      2025-11-13 15:37 true    stale
import_ext              mikras  0.4.84  dev       +f1a4b3db import_ext              2025-11-13 15:18 true    stale
import_fdw              mikras  0.4.84  dev       +f1a4b3db import_fdw              -                -       -
import_plone            mikras  0.4.84  dev       +f1a4b3db import_plone            2025-11-13 15:36 true    stale
import_sagsys           mikras  0.4.84  dev       +f1a4b3db import_sagsys           2025-11-13 15:20 true    stale
import_websys           mikras  0.4.83  master     fdc5ed46 import_websys           2025-10-27 14:36 true    clean
import_webtool          mikras  0.4.84  dev       +f1a4b3db import_webtool          2025-11-13 15:21 true    stale
import_webtoolpublished mikras  0.4.84  dev       +f1a4b3db import_webtoolpublished 2025-11-13 15:34 true    stale
mikras_0_4_73           mikras  0.4.73  master     066dd9d9 app_portal_frontend     2025-05-01 04:53 true    clean
seeds                   mikras  0.4.79  import    +570ea6c2 seeds                   2025-08-13 16:29 false   fail
test                    mikras  0.4.85  dev       +bbb0eed5 test                    2025-11-17 17:01 true    stale *

