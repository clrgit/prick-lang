
module Prick
  module Database
    include Prick

    forward_to_class "Prick.settings", :superuser, :system_conn, :user_conn

    #
    # R D B M S   M E T H O D S
    #
    # RDBMS methods takes a database and optionallly a user (owner) argument
    #

    # Return true if the database exists
    def self.exist?(database)
      system_conn.rdbms.exist? database
    end

    # Create database. Create owner too if absent
    def self.create(database)
      owner = database # Owner always has the same name as the database

      # Create owner if absent
      if !system_conn.role.exist? owner
        # FIXME Should not be created as superuser but that requires that prick
        # is aware of which objects that should be created using the super user
        # and not the database owner
        system_conn.role.create owner, superuser: true, can_login: true, create_role: true
      end

      # Create database
      system_conn.rdbms.create database, owner: owner
    end

    # Ensure that an empty database exists with no users except the owner.
    # Existing databases are hollowed-out instead re-created to not kick
    # existing sessions
    def self.ensure(database)
      owner = database # Owner always has the same name as the database
      if system_conn.rdbms.exist? database
        system_conn.role.drop system_conn.role.list(database: database)
        system_conn.rdbms.empty! database
      else
        create database
      end
    end

    # Drop database and optionally owner. Owner is not dropped if equal to
    # #superuser
    def self.drop(database, owner: false)
      owner = owner ? database : nil
      system_conn.rdbms.drop database
      system_conn.role.drop owner if owner && owner != superuser
    end

    #
    # D A T A B A S E   M E T H O D S
    #
    # Database methods works on the database in Settings
    #

    # Return true if current database is an initialized prick database
    def self.prick?
#     db_conn.schema.exist_relation? "prick", "states"
      super_conn.schema.exist_relation? "prick", "states"
    end

    # Initialize database
    def self.init
      # Run prick build files. prick.sql is mandatory, other absent files are
      # ignored
      PRICK_BUILD_FILENAMES.each { |filename|
        file = File.join Prick::SCHEMA_PRICK_DIRNAME, filename
        if File.exist? file
          user_conn.exec(IO.read(file))
        else
          filename != "prick.sql" or error "Can't find #{file}"
        end
      }
    end

    def self.status(database)
    end
  end
end




#   # Project user (owner) connection. Memoized to connect only once.
#   # TODO Rename. Also rename self.connection
#   def connection(database: nil, username: nil, environment: nil, &block)
#     if @connection.nil?
#       database ||= self.database
#       username ||= self.username
#       environment ||= self.environment
#       !database.nil? or Prick.error "Can't connect to Postgres - no database specified"
#
#       @connection = PgConn.new(database, username)
#
#       # Set database_version/environment/prick members
#       load_database_environment
#
#       # Set environment if undefined and not overridden by :environment
#       self.environment =
#           environment ||
#           Prick.state.environment ||
#           environments.key?(database_environment) && database_environment ||
#           DEFAULT_ENVIRONMENT
#     end
#     if block_given?
#       yield @connection
#     else
#       @connection
#     end
#   end
#
#   # Superuser connection. This is a connection to Postgres using the current
#   # user's credentials. It is assumed that the current user has a postgres
#   # superuser account with the same name as the user's. Memoized to connect
#   # only once
#   def self.connection(&block)
#     @@connection ||= PgConn.new("postgres")
#     if block_given?
#       yield @@connection
#     else
#       @@connection
#     end
#   end



#     # Initialize prick schema
#     init_database database, username, environment
#   end

#   # Setup prick schema
#   def self.init_database(conn = user_conn, database, username, environment)
#     conn.schema.create("prick")
#     PRICK_BUILD_FILES.each { |file|
#       conn.exec(IO.read("#{SCHEMA_PRICK_DIRNAME}/#{file}"))
#     }
#
#     # Add initial build record
#     state = Prick.state # shorthand
#     conn.insert "prick.builds",
#         name: state.name,
#         version: state.version,
#         prick: state.prick_version,
#         branch: state.branch,
#         rev: state.rev(kind: :short),
#         clean: state.clean?,
#         environment: environment || Prick::DEFAULT_ENVIRONMENT,
#         built_at: nil,
#         success: nil
#   end


